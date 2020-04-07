package com.ververica.platform;

import java.time.Duration;
import java.time.Instant;
import java.util.Arrays;
import java.util.Objects;
import java.util.Optional;
import java.util.Random;
import java.util.concurrent.TimeUnit;
import org.apache.flink.api.java.tuple.Tuple0;
import org.apache.flink.api.java.tuple.Tuple4;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.TimeCharacteristic;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.CheckpointConfig.ExternalizedCheckpointCleanup;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.sink.DiscardingSink;
import org.apache.flink.streaming.api.functions.source.SourceFunction;
import org.apache.flink.streaming.api.functions.timestamps.AscendingTimestampExtractor;
import org.apache.flink.streaming.api.functions.windowing.delta.DeltaFunction;
import org.apache.flink.streaming.api.windowing.assigners.GlobalWindows;
import org.apache.flink.streaming.api.windowing.evictors.TimeEvictor;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.api.windowing.triggers.DeltaTrigger;

public class TopSpeedWindowingWithCheckpointing {

  public static void main(String[] args) throws Exception {
    ParameterTool params = ParameterTool.fromArgs(args);
    boolean disableCheckpointing = params.getBoolean("disableCheckpointing", false);
    long checkpointInterval = params.getLong("checkpointInterval", 10_000L);
    Optional<ExternalizedCheckpointCleanup> checkpointRetention =
        Optional.ofNullable(params.get("checkpointRetention", null))
            .map(ExternalizedCheckpointCleanup::valueOf);
    Optional<Duration> failAfterOpt =
        Optional.ofNullable(params.get("failAfter", null))
            .map(Duration::parse); // ISO 8601 format, e.g. PT5S == 5 seconds

    StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
    env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);

    if (!disableCheckpointing) {
      env.enableCheckpointing(checkpointInterval);
    }
    checkpointRetention.ifPresent(
        value -> env.getCheckpointConfig().enableExternalizedCheckpoints(value));

    DataStream<Tuple4<Integer, Integer, Double, Long>> carData = env.addSource(CarSource.create(2));

    int evictionSec = 10;
    double triggerMeters = 50;

    failAfterOpt.ifPresent(
        failAfter -> env.addSource(new FailAfterSource(failAfter)).addSink(new DiscardingSink<>()));

    env.addSource(CarSource.create(2))
        .assignTimestampsAndWatermarks(new CarTimestamp())
        .keyBy(0)
        .window(GlobalWindows.create())
        .evictor(TimeEvictor.of(Time.of(evictionSec, TimeUnit.SECONDS)))
        .trigger(
            DeltaTrigger.of(
                triggerMeters,
                new DeltaFunction<Tuple4<Integer, Integer, Double, Long>>() {
                  private static final long serialVersionUID = 1L;

                  @Override
                  public double getDelta(
                      Tuple4<Integer, Integer, Double, Long> oldDataPoint,
                      Tuple4<Integer, Integer, Double, Long> newDataPoint) {
                    return newDataPoint.f2 - oldDataPoint.f2;
                  }
                },
                carData.getType().createSerializer(env.getConfig())))
        .maxBy(1)
        .print();

    env.execute(
        String.format(
            "TopSpeedWindowingWithCheckpointing(disableCheckpointing=%s,"
                + "checkpointInterval=%s,"
                + "checkpointRetention=%s",
            disableCheckpointing, checkpointInterval, checkpointRetention));
  }

  private static class CarSource implements SourceFunction<Tuple4<Integer, Integer, Double, Long>> {

    private static final long serialVersionUID = 1L;
    private Integer[] speeds;
    private Double[] distances;

    private Random rand = new Random();

    private volatile boolean isRunning = true;

    private CarSource(int numOfCars) {
      speeds = new Integer[numOfCars];
      distances = new Double[numOfCars];
      Arrays.fill(speeds, 50);
      Arrays.fill(distances, 0d);
    }

    private static CarSource create(int cars) {
      return new CarSource(cars);
    }

    @Override
    public void run(SourceContext<Tuple4<Integer, Integer, Double, Long>> ctx) throws Exception {

      while (isRunning) {
        Thread.sleep(100);
        for (int carId = 0; carId < speeds.length; carId++) {
          if (rand.nextBoolean()) {
            speeds[carId] = Math.min(100, speeds[carId] + 5);
          } else {
            speeds[carId] = Math.max(0, speeds[carId] - 5);
          }
          distances[carId] += speeds[carId] / 3.6d;
          Tuple4<Integer, Integer, Double, Long> record =
              new Tuple4<>(carId, speeds[carId], distances[carId], System.currentTimeMillis());
          ctx.collect(record);
        }
      }
    }

    @Override
    public void cancel() {
      isRunning = false;
    }
  }

  private static class CarTimestamp
      extends AscendingTimestampExtractor<Tuple4<Integer, Integer, Double, Long>> {
    private static final long serialVersionUID = 1L;

    @Override
    public long extractAscendingTimestamp(Tuple4<Integer, Integer, Double, Long> element) {
      return element.f3;
    }
  }

  private static class FailAfterSource implements SourceFunction<Tuple0> {

    private final Duration failAfter;

    private volatile boolean isRunning = true;

    public FailAfterSource(Duration failAfter) {
      this.failAfter = Objects.requireNonNull(failAfter);
    }

    @Override
    public void run(SourceContext<Tuple0> sourceContext) throws Exception {
      final Instant deadline = Instant.now().plus(failAfter);

      while (isRunning && Instant.now().isBefore(deadline)) {
        Thread.sleep(100);
      }

      throw new FailAfterException(failAfter);
    }

    @Override
    public void cancel() {
      isRunning = false;
    }

    public static class FailAfterException extends Exception {
      public FailAfterException(Duration failAfter) {
        super(String.format("Failed after %s", failAfter));
      }
    }
  }
}
