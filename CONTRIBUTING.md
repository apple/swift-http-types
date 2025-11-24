## Legal

By submitting a pull request, you represent that you have the right to license
your contribution to Apple and the community, and agree by submitting the patch
that your contributions are licensed under the Apache 2.0 license (see
`LICENSE.txt`).

## How to submit a bug report

Please ensure to specify the following:

* Swift HTTP Types commit hash
* Contextual information (e.g. what you were trying to achieve with Swift HTTP Types)
* Simplest possible steps to reproduce
  * More complex the steps are, lower the priority will be.
  * A pull request with failing test case is preferred, but it's just fine to paste the test case into the issue description.
* Anything that might be relevant in your opinion, such as:
  * Swift version or the output of `swift --version`
  * OS version and the output of `uname -a`
  * Network configuration

### Example

```
Commit hash: b17a8a9f0f814c01a56977680cb68d8a779c951f

Context:
While testing my application that uses with Swift HTTP Types, I noticed that ...

Steps to reproduce:
1. ...
2. ...
3. ...
4. ...

$ swift --version
Swift version 5.9-dev (LLVM a93e6b3cd9a083f, Swift 6cdd8f7eed07e21)
Target: aarch64-unknown-linux-gnu

Operating system: Ubuntu Linux 22.04 aarch64

$ uname -a
Linux beefy.machine 5.15.110 #2 SMP Mon May 1 18:48:38 UTC 2023 aarch64 aarch64 aarch64 GNU/Linux

My system has IPv4 disabled.
```

## Writing a Patch

A good patch is:

1. Concise, and contains as few changes as needed to achieve the end result.
2. Tested, ensuring that any tests provided failed before the patch and pass after it.
3. Documented, adding API documentation as needed to cover new functions and properties.
4. Accompanied by a great commit message, using our commit message template.

## How to contribute your work

Please open a pull request at https://github.com/apple/swift-http-types. Make sure the CI passes, and then wait for code review.
