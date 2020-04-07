package com.ververica.platform;

import org.apache.flink.streaming.api.checkpoint.ListCheckpointed;

import com.ververica.platform.entities.Commit;
import org.kohsuke.github.GHCommit;
import org.kohsuke.github.PagedIterable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Collections;
import java.util.Date;
import java.util.List;

public class GithubCommitSource extends GithubSource<Commit> implements ListCheckpointed<Instant> {

    private static final Logger LOG = LoggerFactory.getLogger(GithubCommitSource.class);

    private static final int PAGE_SIZE = 100;
    private static final long POLL_INTERVAL_MILLI = 10_000;

    private final Instant startTime;
    private Date lastTime;
    private volatile boolean running = true;

    public GithubCommitSource(String repoName) {
        super(repoName);
        this.startTime = Instant.now().minus(1, ChronoUnit.DAYS);
        lastTime = Date.from(startTime); // might be overriding during restore
    }

    public GithubCommitSource(String repoName, Instant startTime) {
        super(repoName);
        this.startTime = startTime;
        lastTime = Date.from(startTime); // might be overridden during restore
    }

    @Override
    public void run(SourceContext<Commit> sourceContext) throws IOException, InterruptedException {

        LOG.info("Starting to query for Github commits from " + startTime);

        while (running) {
            LOG.info("Fetching commits.");
            PagedIterable<GHCommit> commits = repo.queryCommits().since(lastTime).list();
            Date lastCommitDate = lastTime;
            for (GHCommit ghCommit : commits.withPageSize(PAGE_SIZE)) {
                lastCommitDate = ghCommit.getCommitDate();

                Commit commit = Commit.builder()
                        .author(ghCommit.getAuthor().getName())
                        .timestamp(lastCommitDate.getTime())
                        .build();

                sourceContext.collectWithTimestamp(commit, lastCommitDate.getTime());
            }
            lastTime = lastCommitDate;
            Thread.sleep(POLL_INTERVAL_MILLI);
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
        //this is only called when restoring, hence state should not be empty
        lastTime = Date.from(state.get(0));
    }
}