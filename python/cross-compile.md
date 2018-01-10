# Cross Compile Python

## 1. Configure

export PATH=/path/to/cross-compiler/bin:$PATH

./configure --host=arm-linux-musleabi --build=x86_64-linux-gnu --prefix=/path/to/prefix \
    --disable-ipv6 ac_cv_file__dev_ptmx=no ac_cv_file__dev_ptc=no                    \
    ac_cv_have_long_long_format=yes
    
## 2. Patch the souces like this


```
diff --git a/packages/Python-2.7.5/setup.py b/packages/Python-2.7.5/setup.py
index 716f08e..ca8b141 100644
--- a/packages/Python-2.7.5/setup.py
+++ b/packages/Python-2.7.5/setup.py

@@ -552,6 +556,11 @@ class PyBuildExt(build_ext):
         if host_platform in ['darwin', 'beos']:
             math_libs = []

+        # Insert libraries and headers from embedded root file system (RFS)
+        if 'RFS' in os.environ:
+            lib_dirs += [os.environ['RFS'] + '/usr/lib']
+            inc_dirs += [os.environ['RFS'] + '/usr/include']
+
         # XXX Omitted modules: gl, pure, dl, SGI-specific modules

         #
``` 
## Build
1. copy the 'Setup' file in Modules/Setup
2. export RFS=/path/to/cross-compiler/sys-root
3. make
4. make install

Enjoy
