package com.ververica.platform;

import static org.elasticsearch.common.xcontent.XContentFactory.jsonBuilder;

import com.ververica.platform.entities.Commit;
import com.ververica.platform.entities.ComponentChangedSummary;
import com.ververica.platform.io.source.GithubCommitSource;
import com.ververica.platform.operators.ComponentChangedAggeragator;
import com.ververica.platform.operators.ComponentChangedSummarizer;
import com.ververica.platform.operators.ComponentExtractor;
import java.io.IOException;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import org.apache.flink.api.common.functions.RuntimeContext;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.TimeCharacteristic;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.CheckpointConfig;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.connectors.elasticsearch.ElasticsearchSinkFunction;
import org.apache.flink.streaming.connectors.elasticsearch.RequestIndexer;
import org.apache.flink.streaming.connectors.elasticsearch7.ElasticsearchSink;
import org.apache.http.HttpHost;
import org.elasticsearch.action.update.UpdateRequest;
import org.elasticsearch.common.xcontent.XContentBuilder;

public class FlinkCommitProgram {

  public static final String APACHE_FLINK_REPOSITORY = "apache/flink";

  public static void main(String[] args) throws Exception {

    ParameterTool params = ParameterTool.fromArgs(args);

    // Sink
    String esHost = params.get("es-host", "elasticsearch-master-headless.vvp.svc");
    int esPort = params.getInt("es-port", 9200);

    // Source
    long delayBetweenQueries = params.getLong("poll-interval", 1000L);
    String startDateString = params.get("start-date", "");

    StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

    env.enableCheckpointing(10_000);
    env.getCheckpointConfig()
        .enableExternalizedCheckpoints(
            CheckpointConfig.ExternalizedCheckpointCleanup.RETAIN_ON_CANCELLATION);

    env.setStreamTimeCharacteristic(TimeCharacteristic.EventTime);

    DataStream<Commit> commits =
        env.addSource(getGithubCommitSource(delayBetweenQueries, startDateString))
            .name("flink-commit-source")
            .uid("flink-commit-source");

    DataStream<ComponentChangedSummary> componentCounts =
        commits
            .flatMap(new ComponentExtractor())
            .name("component-extractor")
            .keyBy(componentChanged -> componentChanged.getName())
            .timeWindow(Time.hours(1))
            .aggregate(new ComponentChangedAggeragator(), new ComponentChangedSummarizer())
            .name("component-activity-window")
            .uid("component-activity-window");

    componentCounts.addSink(getElasticsearchSink(esHost, esPort));
    componentCounts.printToErr();

    env.execute("Apache Flink Project Dashboard");
  }

  private static GithubCommitSource getGithubCommitSource(
      final long delayBetweenQueries, final String startDateString) {
    final GithubCommitSource githubCommitSource;
    if (startDateString.isEmpty()) {
      githubCommitSource =
          new GithubCommitSource(APACHE_FLINK_REPOSITORY, Instant.now(), delayBetweenQueries);
    } else {
      Instant startDate = Instant.parse(startDateString);
      githubCommitSource =
          new GithubCommitSource(APACHE_FLINK_REPOSITORY, startDate, delayBetweenQueries);
    }
    return githubCommitSource;
  }

  private static ElasticsearchSink getElasticsearchSink(final String host, final int port)
      throws UnknownHostException {

    List<HttpHost> transportAddresses = new ArrayList<>();
    transportAddresses.add(new HttpHost(InetAddress.getByName(host), port));

    ElasticsearchSink.Builder builder =
        new ElasticsearchSink.Builder(
            transportAddresses,
            new ElasticsearchSinkFunction<ComponentChangedSummary>() {

              @Override
              public void process(
                  ComponentChangedSummary element, RuntimeContext ctx, RequestIndexer indexer) {

                XContentBuilder source;
                try {
                  source =
                      jsonBuilder()
                          .startObject()
                          .field("component", element.getComponentName())
                          .timeField("windowStart", element.getWindowStart())
                          .timeField("windowEnd", element.getWindowEnd())
                          .field("linesChanged", element.getLinesChanged())
                          .endObject();
                } catch (IOException e) {
                  throw new RuntimeException("error serializing component summery", e);
                }

                UpdateRequest upsertComponentUpdateSummary =
                    new UpdateRequest(
                        "github_stats-2019",
                        String.valueOf(
                            Objects.hash(element.getComponentName(), element.getWindowStart())));
                upsertComponentUpdateSummary.doc(source).upsert(source);

                indexer.add(upsertComponentUpdateSummary);
              }
            });

    builder.setBulkFlushMaxActions(1);

    return builder.build();
  }
}
