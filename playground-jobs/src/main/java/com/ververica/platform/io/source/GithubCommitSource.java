package com.ververica.platform.io.source;

import com.ververica.platform.entities.Commit;
import com.ververica.platform.entities.File;
import java.io.IOException;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.stream.Collectors;
import org.apache.flink.streaming.api.checkpoint.ListCheckpointed;
import org.apache.flink.streaming.api.watermark.Watermark;
import org.kohsuke.github.GHCommit;
import org.kohsuke.github.PagedIterable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class GithubCommitSource extends GithubSource<Commit> implements ListCheckpointed<Instant> {

  private static final Logger LOG = LoggerFactory.getLogger(GithubCommitSource.class);

  private static final int PAGE_SIZE = 100;
  private static final long POLL_INTERVAL_MILLI = 10_000;

  private final Instant startTime;
  private Date lastTime;
  private volatile boolean running = true;

  public GithubCommitSource(String repoName) {
    this(repoName, Instant.now().minus(1, ChronoUnit.DAYS));
  }

  public GithubCommitSource(String repoName, Instant startTime) {
    super(repoName);
    this.startTime = startTime;
    lastTime = Date.from(startTime);
  }

  @Override
  public void run(SourceContext<Commit> ctx) throws IOException {
    LOG.info("Starting to query for Github commits from " + startTime);

    while (running) {
      LOG.info("Fetching commits.");
      PagedIterable<GHCommit> commits = repo.queryCommits().since(lastTime).list();
      Date lastCommitDate = lastTime;

      synchronized (ctx.getCheckpointLock()) {
        for (GHCommit ghCommit : commits.withPageSize(PAGE_SIZE)) {
          lastCommitDate = ghCommit.getCommitDate();

          Commit commit =
              Commit.builder()
                  .author(ghCommit.getAuthor().getName())
                  .filesChanged(
                      ghCommit.getFiles().stream()
                          .map(
                              file ->
                                  File.builder()
                                      .filename(file.getFileName())
                                      .linesChanged(file.getLinesChanged())
                                      .build())
                          .collect(Collectors.toList()))
                  .build();

          ctx.collectWithTimestamp(commit, lastCommitDate.getTime());
        }

        lastTime = lastCommitDate;
        ctx.emitWatermark(new Watermark(lastTime.getTime()));
      }

      try {
        Thread.sleep(POLL_INTERVAL_MILLI);
      } catch (InterruptedException e) {
        running = false;
      }
    }
  }

  @Override
  public void cancel() {
    running = false;
  }

  @Override
  public List<Instant> snapshotState(long checkpointId, long timestamp) {
    return Collections.singletonList(lastTime.toInstant());
  }

  @Override
  public void restoreState(List<Instant> state) {
    lastTime = Date.from(state.get(0));
  }
}
