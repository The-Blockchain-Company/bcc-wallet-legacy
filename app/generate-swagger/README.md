# swagger-file

> Output Swagger spec (2.0) file corresponding to a given API


# How to Use

```
$ bcc-generate-swagger-file --help

Usage: bcc-generate-swagger-file (-t|--target API) [-o|--output-file FILEPATH]

Available options:
  -t,--target API           Target API with version (e.g. 'wallet@v1'...)
  -o,--output-file FILEPATH Output file, default to: swagger.json
  -h,--help                 Show this help text

Examples:
  bcc-generate-swagger-file --target wallet@v1
  bcc-generate-swagger-file -t wallet@v1 -o v1.json
```


# License

MIT - Copyright (c) 2018 TBCO
