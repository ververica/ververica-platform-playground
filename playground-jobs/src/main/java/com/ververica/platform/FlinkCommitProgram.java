package com.ververica.platform;

import com.ververica.platform.io.source.GithubCommitSource;
import com.ververica.platform.operators.ComponentExtractor;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.api.windowing.triggers.ContinuousEventTimeTrigger;

public class FlinkCommitProgram {

  public static void main(String[] args) throws Exception {

    StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

    env.addSource(new GithubCommitSource("apache/flink"))
        .name("flink-commit-source")
        .uid("flink-commit-source")
        .flatMap(new ComponentExtractor())
        .name("component-extractor")
        .keyBy("name")
        .timeWindow(Time.days(1))
        .trigger(ContinuousEventTimeTrigger.of(Time.minutes(1)))
        .sum("linesChanged")
        .name("component-activity-window")
        .uid("component-activity-window")
        .print();

    env.execute("Apache Flink Project Dashboard");
  }
}
