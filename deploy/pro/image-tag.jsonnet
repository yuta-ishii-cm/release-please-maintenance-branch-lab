local env = std.native('env');
local defaultTag = 'v1.2.0'; // x-release-please-version

{
  tag: env('IMAGE_TAG', defaultTag),
}
