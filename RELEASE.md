# Release Process

The kubernetes-mixin project is released on an as-needed basis. The process is as follows:

1. Verify that `master` branch CI checks are green
1. An OWNER runs `git tag -s -a $VERSION -m "$VERSION"` and pushes the tag with `git push origin $VERSION` where `$VERSION` looks like `version-1.5.3`
1. Release automation triggers automatically when new tags matching `version-*` are pushed
