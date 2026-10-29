local env = std.native('env');
local defaultTag = 'v1.0.1'; // x-release-please-version

{
  tag: env('IMAGE_TAG', defaultTag),
}
