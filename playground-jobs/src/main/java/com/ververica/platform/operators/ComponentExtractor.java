package com.ververica.platform.operators;

import com.ververica.platform.entities.Commit;
import com.ververica.platform.entities.ComponentChanged;
import com.ververica.platform.entities.FileChanged;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.apache.flink.api.common.functions.FlatMapFunction;
import org.apache.flink.util.Collector;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ComponentExtractor implements FlatMapFunction<Commit, ComponentChanged> {

  private static final Logger LOG = LoggerFactory.getLogger(ComponentExtractor.class);

  private static final Pattern COMPONENT = Pattern.compile("(?<component>.*)\\/src\\/.*");

  @Override
  public void flatMap(Commit value, Collector<ComponentChanged> out) throws Exception {
    for (FileChanged file : value.getFilesChanged()) {
      Matcher matcher = COMPONENT.matcher(file.getFilename());

      // TODO replace by metric
      if (!matcher.matches()) {
        LOG.debug("No component found for file {}", file.getFilename());
        return;
      }

      String componentName = matcher.group("component");

      ComponentChanged component =
          ComponentChanged.builder()
              .name(componentName)
              .linesChanged(file.getLinesChanged())
              .build();

      out.collect(component);
    }
  }
}
