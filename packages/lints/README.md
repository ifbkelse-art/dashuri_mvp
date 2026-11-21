# dashuri_lints

The one place where Dashuri's analysis rules live. Every package adds `dashuri_lints` as a dev dependency and starts its `analysis_options.yaml` with:

```yaml
include: package:dashuri_lints/analysis_options.yaml
```

Change rules here, not in individual packages.
