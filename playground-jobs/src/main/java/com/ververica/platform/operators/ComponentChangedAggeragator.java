package com.ververica.platform.operators;

import com.ververica.platform.entities.ComponentChanged;
import org.apache.flink.api.common.functions.AggregateFunction;

public class ComponentChangedAggeragator
    implements AggregateFunction<ComponentChanged, ComponentChanged, ComponentChanged> {

  @Override
  public ComponentChanged createAccumulator() {
    return new ComponentChanged();
  }

  @Override
  public ComponentChanged add(final ComponentChanged componentChanged, final ComponentChanged acc) {
    return ComponentChanged.builder()
        .name(componentChanged.getName())
        .linesChanged(componentChanged.getLinesChanged() + acc.getLinesChanged())
        .build();
  }

  @Override
  public ComponentChanged getResult(final ComponentChanged componentChanged) {
    return componentChanged;
  }

  @Override
  public ComponentChanged merge(final ComponentChanged acc1, final ComponentChanged acc2) {
    return ComponentChanged.builder()
        .name(acc1.getName())
        .linesChanged(acc1.getLinesChanged() + acc2.getLinesChanged())
        .build();
  }
}
