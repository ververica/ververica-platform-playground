package com.ververica.platform;

import org.apache.flink.configuration.Configuration;
import org.apache.flink.streaming.api.datastream.DataStreamSource;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

import com.ververica.platform.entities.Commit;

public class FlinkCommitProgram {

  public static void main(String[] args) throws Exception {

    StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

    DataStreamSource<Commit> commitStream = env.addSource(new GithubCommitSource("apache/flink"));

    commitStream.print();

    env.execute();

  }

}
