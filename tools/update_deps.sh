echo Updating tuple
cd deps/tuple
git pull
echo done
echo

echo Updating the sdk with depot_tools
cd ..
#gclient sync
echo done
echo

cd ..

echo Copying and transforming sdk .packages to be useful to this repo
cat deps/sdk/.packages | sed 's/:/:deps\/sdk\//' > .packages
echo done
echo

echo Adding tuple to .packages
echo 'tuple:deps/tuple/lib' >> .packages
echo done
echo
