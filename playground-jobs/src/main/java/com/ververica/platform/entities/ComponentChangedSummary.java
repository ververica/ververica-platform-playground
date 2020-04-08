package com.ververica.platform.entities;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class ComponentChangedSummary {

  private long windowStart;
  private long windowEnd;
  private String componentName;
  private long linesChanged;
}
