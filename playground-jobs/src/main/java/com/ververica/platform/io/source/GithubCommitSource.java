package com.ververica.platform.io.source;

import com.ververica.platform.entities.Commit;
import com.ververica.platform.entities.FileChanged;
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
import org.kohsuke.github.GHUser;
import org.kohsuke.github.PagedIterable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class GithubCommitSource extends GithubSource<Commit> implements ListCheckpointed<Instant> {

  private static final Logger LOG = LoggerFactory.getLogger(GithubCommitSource.class);

  private static final int PAGE_SIZE = 100;

  private final long pollIntervalMillis;

  private Instant lastTime;
  private volatile boolean running = true;

  public GithubCommitSource(String repoName) {
    this(repoName, Instant.now(), 1000);
  }

  public GithubCommitSource(String repoName, Instant startTime, long pollIntervalMillis) {
    super(repoName);
    lastTime = startTime;
    this.pollIntervalMillis = pollIntervalMillis;
  }

  @Override
  public void run(SourceContext<Commit> ctx) throws IOException {
    while (running) {
      Instant until = getUntilFor(lastTime);
      LOG.info("Fetching commits since {} until {}", lastTime, until);
      PagedIterable<GHCommit> commits =
          repo.queryCommits().since(Date.from(lastTime)).until(Date.from(until)).list();
      Date lastCommitDate;

      synchronized (ctx.getCheckpointLock()) {
        for (GHCommit ghCommit : commits.withPageSize(PAGE_SIZE)) {
          lastCommitDate = ghCommit.getCommitDate();

          GHUser author = ghCommit.getAuthor();
          Commit commit =
              Commit.builder()
                  .author(author != null ? author.getName() : "unknown")
                  .filesChanged(
                      ghCommit.getFiles().stream()
                          .map(
                              file ->
                                  FileChanged.builder()
                                      .filename(file.getFileName())
                                      .linesChanged(file.getLinesChanged())
                                      .build())
                          .collect(Collectors.toList()))
                  .timestamp(lastCommitDate)
                  .build();

          // TODO consider materializing and sorting for less out-of-orderness

          ctx.collectWithTimestamp(commit, lastCommitDate.getTime());
        }

        lastTime = until;
        ctx.emitWatermark(new Watermark(lastTime.toEpochMilli()));
      }
      try {
        Thread.sleep(pollIntervalMillis);
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
    return Collections.singletonList(lastTime);
  }

  @Override
  public void restoreState(List<Instant> state) {
    lastTime = state.get(0);
  }

  public Instant getUntilFor(Instant since) {

    Instant maybeUntil = since.plus(1, ChronoUnit.HOURS);

    if (maybeUntil.compareTo(Instant.now()) > 0) {
      return Instant.now();
    } else {
      return maybeUntil;
    }
  }
}
