package com.ververica.platform.operators;

import com.ververica.platform.entities.ComponentChanged;
import com.ververica.platform.entities.ComponentChangedSummary;
import org.apache.flink.streaming.api.functions.windowing.WindowFunction;
import org.apache.flink.streaming.api.windowing.windows.TimeWindow;
import org.apache.flink.util.Collector;

public class ComponentChangedSummarizer
    implements WindowFunction<ComponentChanged, ComponentChangedSummary, String, TimeWindow> {

  @Override
  public void apply(
      final String s,
      final TimeWindow window,
      final Iterable<ComponentChanged> input,
      final Collector<ComponentChangedSummary> out)
      throws Exception {

    // only one record due to pre-aggregation
    ComponentChanged componentChanged = input.iterator().next();

    ComponentChangedSummary summary =
        ComponentChangedSummary.builder()
            .componentName(componentChanged.getName())
            .linesChanged(componentChanged.getLinesChanged())
            .windowStart(window.getStart())
            .windowEnd(window.getEnd())
            .build();

    out.collect(summary);
  }
}
