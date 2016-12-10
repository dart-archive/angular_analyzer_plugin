echo Updating pub deps
cd deps
pub get
echo done
echo

echo Updating the sdk with depot_tools
gclient sync
echo done
echo

cd ..

echo Copying and transforming sdk .packages to be useful to this repo
cat deps/sdk/.packages | grep -v '^test' | sed 's/:/:deps\/sdk\//' > .packages
echo done
echo

echo Copying pub .packages to be useful to this repo
cat deps/.packages >> .packages
echo done
echo

echo Adding analyzer plugin to .packages
echo 'angular_analyzer_plugin:analyzer_plugin/lib' >> .packages
echo done
echo

echo Adding server to .packages
echo 'angular_analyzer_server_plugin:server_plugin/lib' >> .packages
echo done
echo
