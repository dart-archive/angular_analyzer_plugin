echo Creating deps directory
mkdir deps
cd deps
echo done
echo

echo Pulling down tuple
git clone https://github.com/kseo/tuple.git tuple
echo done
echo

echo Using depot tools to pull in the SDK
gclient config https://github.com/dart-lang/sdk.git
gclient sync
echo done

./tools/update_deps.sh
