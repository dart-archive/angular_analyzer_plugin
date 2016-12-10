echo Using depot tools to pull in the SDK
gclient config https://github.com/dart-lang/sdk.git
gclient sync
echo done

cd ..

./tools/update_deps.sh
