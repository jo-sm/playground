# idris2-homebrew

It seems that [Mac M1+ don't support the standard version of Chez Scheme](https://github.com/cisco/ChezScheme/issues/544) (Racket does but it's because it has some custom code to do it). The current Homebrew formula for Idris2 uses Chez Scheme, with no way to tell it to use the Racket boostrapping instead, so installing normally doesn't work. Things are further complicated by the fact that you need to tell `make bootstrap-racket` which prefix you're going to use, and since Brew is the one that maintains most libraries you'd need to give it the prefix of a Homebrew directory, not ideal when installing outside of Homebrew.

The included `idris2.rb` has the following changes:

- Replaces `make boostrap` with `make boostrap-racket`
- Removes the dependency on `chezscheme`
- Adds `env :std` since we can't add the full Racket setup as a dependency using `depends_on`, as it's from a Cask (I had a lot of trouble using `minimal-racket`). The same flag would presumably be needed if a non-Homebrew installation was used.

As a patch:

```patch
diff --git a/Formula/idris2.rb b/Formula/idris2.rb
index daf314eefce..f0618cf6f4d 100644
--- a/Formula/idris2.rb
+++ b/Formula/idris2.rb
@@ -7,6 +7,8 @@ class Idris2 < Formula
   revision 1
   head "https://github.com/idris-lang/Idris2.git", branch: "main"

+  env :std
+
   bottle do
     sha256 cellar: :any,                 big_sur:      "bd0fe93d2cf1992c825305e9fbc451cc900aacd15e5d2fcf8ca9a14c1abc9385"
     sha256 cellar: :any,                 catalina:     "9a677678a11af3aa67e96cc31592b6690cbaa801fb16200f019e04ef582c8815"
@@ -15,13 +17,11 @@ class Idris2 < Formula

   depends_on "coreutils" => :build
   depends_on "gmp" => :build
-  depends_on "chezscheme"
   uses_from_macos "zsh" => :build, since: :mojave

   def install
     ENV.deparallelize
-    scheme = Formula["chezscheme"].bin/"chez"
-    system "make", "bootstrap", "SCHEME=#{scheme}", "PREFIX=#{libexec}"
+    system "make", "bootstrap-racket", "PREFIX=#{libexec}"
     system "make", "install", "PREFIX=#{libexec}"
     bin.install_symlink libexec/"bin/idris2"
     lib.install_symlink Dir["#{libexec}/lib/#{shared_library("*")}"]
```
