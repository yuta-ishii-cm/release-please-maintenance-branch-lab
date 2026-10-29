local env = std.native('env');
local defaultTag = 'v1.1.0'; // x-release-please-version

{
  tag: env('IMAGE_TAG', defaultTag),
}
