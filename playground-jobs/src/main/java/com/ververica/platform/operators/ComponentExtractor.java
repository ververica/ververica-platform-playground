package com.ververica.platform.operators;

import com.ververica.platform.entities.Commit;
import com.ververica.platform.entities.Component;
import com.ververica.platform.entities.File;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.apache.flink.api.common.functions.FlatMapFunction;
import org.apache.flink.util.Collector;

public class ComponentExtractor implements FlatMapFunction<Commit, Component> {

  private static final Pattern COMPONENT = Pattern.compile("(.+\\/)*(<component>?.*)\\/src");

  @Override
  public void flatMap(Commit value, Collector<Component> out) throws Exception {
    for (File file : value.getFilesChanged()) {
      Matcher matcher = COMPONENT.matcher(file.getFilename());
      String componentName = matcher.group("component");

      if (componentName == null) {
        componentName = file.getFilename();
      }

      Component component =
          Component.builder().name(componentName).linesChanged(file.getLinesChanged()).build();

      out.collect(component);
    }
  }
}
