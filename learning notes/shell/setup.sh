#!/bin/sh

platform=$(uname)
case "$platform" in
    Darwin)
	platform='mac'
	;;
    CYGWIN*)
	platform='windows'
	;;
    *)
	;;
esac

pkg_dir=$(pwd)/pkgs
local_dir=$(pwd)/local
local_bin=$local_dir/bin
data_dir=$(pwd)/data
repo=http://10.32.52.92/manual/resources/tod_setup

mkdir -p $pkg_dir 2>/dev/null
mkdir -p $local_dir 2>/dev/null
mkdir -p $local_bin 2>/dev/null
mkdir -p $data_dir 2>/dev/null

export PATH="$local_bin:$PATH"

# jdk
export LOCAL_JAVA_HOME=$local_bin/jdk
if [ -z $JAVA_HOME ]; then
    JAVA_HOME=$LOCAL_JAVA_HOME
fi
export PATH=$JAVA_HOME/bin:$PATH

# android adk
export LOCAL_ANDROID_HOME=$local_bin/android_sdk
if [ -z $ANDROID_HOME ]; then
    ANDROID_HOME=$LOCAL_ANDROID_HOME
fi

export PATH=$ANDROID_HOME/tools:$PATH
export PATH=$ANDROID_HOME/platform-tools:$PATH
export PATH=$ANDROID_HOME/build-tools:$PATH

# node
export NODE_HOME=$local_bin/node
export PATH=$NODE_HOME:$PATH
export PATH=$NODE_HOME/bin:$PATH

# appium
export PATH=$(pwd)/node_modules/.bin:$PATH

export local_include=$local_dir/include
export local_lib=$local_dir/lib
export libxml2_CFLAGS="-I$local_include/libxml2"
export libxml2_LIBS="-L$local_lib -lxml2"
export libplist_CFLAGS="-I$local_include"
export libplist_LIBS="-L$local_lib -lplist"
export libplistmm_CFLAGS="-I$local_include/libxml2"
export libplistmm_LIBS="-L$local_lib -lplist++ -lplist"
export libusbmuxd_CFLAGS="-I$local_include"
export libusbmuxd_LIBS="-L$local_lib -lusbmuxd"
export openssl_CFLAGS="-I$local_include"
export openssl_LIBS="-L$local_lib -lssl -lcrypto -lz"

function gen_env() {
cat > env.sh << EOF
#!/bin/sh

export local_bin="$local_bin"
export platform="$platform"
export ANDROID_HOME="$ANDROID_HOME"
export PATH="$PATH"

EOF

}

function gen_common() {
cat > common.sh << "EOF"
#!/bin/sh

source ./env.sh

hub_list=('10.32.52.92:4444' 'xia01-i01-hub01:5555' 'qa-sl6-cat01.od.ab-soft.net:4444', '10.62.19.62:4444')

function die() {
    echo $1
    exit -1
}

function select_hub() {
    while true; do
	echo please choose a hub:
	for i in ${!hub_list[@]}; do
	    hub_host=$(echo ${hub_list[$i]} | cut -d';' -f 1)
	    echo $i\) $hub_host
	done

	read choice
	if [ $choice -ge 0 ] && [ $choice -lt ${#hub_list[@]} ]; then
	    echo you choose: ${hub_list[$choice]}
	    break
	fi
    done

    hub_host=$(echo ${hub_list[$choice]} | cut -d':' -f 1)
    hub_port=$(echo ${hub_list[$choice]} | cut -d':' -f 2)
}

function select_local_ip() {
    if [[ $platform == 'windows' ]]; then
	# ip_list=($(ipconfig | grep -v '127.0.0.*' | grep -v '192.*' | grep 'IPv4 Address' |
	ip_list=($(ipconfig | grep 'IPv4 Address' |
	    perl -n -e '/IPv4 Address.*: (.*)/ && print "$1 "'))
    elif [[ $platform == 'mac' ]]; then
	# ip_list=($(ifconfig | grep 'inet ' | grep -v '127.0.0.*' |
	ip_list=($(ifconfig | grep 'inet ' |
	    sed -e 's/inet \(.*\) netmask .*/\1/g' | xargs))
    else  # linux
	die "unknown platform, unable to detect ip addr!"
    fi

    if [ ${#ip_list[@]} -eq 0 ]; then
	die "Error, no ip assigned to this machine!"
    elif [ ${#ip_list[@]} -eq 1 ]; then
	local_ip=${ip_list[0]}
    else
	while true; do
	    echo please choose ip addr:
	    for i in ${!ip_list[@]}; do
		echo $i\) ${ip_list[$i]}
	    done

	    read choice

	    if [ $choice -ge 0 ] && [ $choice -lt ${#ip_list[@]} ]; then
		local_ip=${ip_list[$choice]}
		break
	    fi
	done
    fi

    echo you choose ip: $local_ip
}

EOF
}

function cmp_ver() {
    first=$1
    second=$2
    large_one=$(printf "$first\n$second" | sort -t '.' -n | tail -n 1)
    [[ "$first" = "$large_one" ]]
}

function install_pkg() {
    pkg_name=$1
    cur_dir=$(pwd)
    cd $TMPDIR

    pkg_url=$repo/${pkg_name}.tar.gz
    curl $pkg_url > ${pkg_name}.tar.gz
    tar -zxf ${pkg_name}.tar.gz
    cd $pkg_name
    echo building $pkg_name

    if [[ $pkg_name == 'openssl' ]]; then
	rm -rf $local_dir/ssl/ >/dev/null 2>&1
        ./Configure darwin64-x86_64-cc --prefix=$local_dir >/dev/null 2>&1 && \
	    make -j 4 >/dev/null 2>&1 && \
	    make install >/dev/null 2>&1
	ret=$?
    elif [[ $pkg_name == "libxml2" ]]; then
	./configure --prefix=$local_dir \
	    --with-python=$local_dir/plib \
	    --with-python-install-dir=$local_dir/plib >/dev/null 2>&1 && \
	    make -j 4 >/dev/null 2>&1 && make install >/dev/null 2>&1
	ret=$?
    else
	./configure --prefix=$local_dir >/dev/null 2>&1 &&  make -j 4 >/dev/null 2>&1 &&  make install >/dev/null 2>&1
	# ./configure --prefix=$local_dir &&  make -j 4 >/dev/null &&  make install

	# don't know why, sometimes it worth a second try.
	if [ ! $? -eq 0 ]; then
	    # ./configure --prefix=$local_dir &&  make -j 4 >/dev/null &&  make install
	    ./configure --prefix=$local_dir >/dev/null 2>&1 &&  make -j 4 >/dev/null 2>&1 &&  make install >/dev/null 2>&1
	fi

	ret=$?
    fi

    if [ ! $ret -eq 0 ]; then
	echo failed to build $pkg_name!
    else
	echo $pkg_name installed.
    fi

    cd $cur_dir

    return $ret
}

function get_pkg() {
    pkg_name=$1
    if [[ $pkg_name == "jdk" ]] || [[ $pkg_name == "chromedriver" ]] || 
	[[ $pkg_name == "android_sdk" ]] || [[ $pkg_name == 'node' ]]; then
	pkg_url=$repo/$platform
    else
	pkg_url=$repo
    fi
    pkg_name=$pkg_name.tar.gz
    pkg_url=$pkg_url/$pkg_name

    if [ ! -d $pkg_dir ]; then
	mkdir -p $pkg_dir
    fi

    echo pkg: $pkg_url
    curl $pkg_url > $pkg_dir/$pkg_name || (echo "Failed downloading $pkg_name!" && return 1)
}

function check_xcode() {
    printf "Checking xcode..."
    xcode-select -p >/dev/null 2>&1 || return 1
    xcode_ver=$(xcodebuild -version  | grep Xcode | cut -d' ' -f 2)
    if [ -z "$xcode_ver" ]; then
        echo "xcode not found! you should install xcode first, please go to https://developer.apple.com/download/ to install xcode first!"
        die "error: install xcode first!"
    fi
    return 0
}

function check_ios_tools() {
    idevice_id=$(which idevice_id)
    idevicename=$(which idevicename)
    ideviceinfo=$(which ideviceinfo)

    [[ ! -z "$idevice_id" ]] && [[ ! -z "$idevicename" ]] && [[ ! -z "$ideviceinfo" ]]
}

function check_java() {
    if [[ $platform == 'mac' ]]; then
	test -f $local_bin/jdk/bin/java
    else
	which java >/dev/null 2>&1
    fi
}

function check_android_sdk() {
    adb version >/dev/null 2>&1
}

function check_node() {
    [[ $(node -v 2>/dev/null) > 'v6.0.0' ]]
}

function check_and_install_appium() {
    printf 'checking appium...'
    if [[ $platform == 'mac' ]]; then
        xcode_ver=$(xcodebuild -version  | grep Xcode | cut -d' ' -f 2)
        cmp_ver $xcode_ver 8.3.0

        if [ $? -eq 0 ]; then
            appium_ver=3.0.4
        else
            appium_ver=1.5.3
        fi
    else
        appium_ver=1.5.3
    fi

    which appium >/dev/null 2>&1 || setup_appium $appium_ver

    if [[ "$appium_ver" = "3.0.4" ]]; then
	if [[ "$(appium --version)" != "3.0.4" ]]; then
	    setup_appium $appium_ver
	else
	    echo OK
	fi
    else
	cmp_ver $(appium --version) ${appium_ver} && echo OK || setup_appium $appium_ver
    fi
}

function check_chromedriver() {
    which chromedriver > /dev/null 2>&1
}

function check_selenium_server_standalone() {
    ls $local_bin/selenium_server_standalone.jar > /dev/null 2>&1
}

function setup_ios_tools() {
    install_pkg autoconf &&
    install_pkg automake &&
    install_pkg libtool &&
    install_pkg libxml2 &&
    install_pkg libplist &&
    install_pkg libusbmuxd &&
    install_pkg openssl &&
    install_pkg libimobiledevice
}

function setup_common() {
    pkg=$1
    get_pkg $pkg && tar -zxf $pkg_dir/$pkg.tar.gz -C $local_bin
}

function setup_java() {
    setup_common jdk
}

function setup_android_sdk() {
    setup_common android_sdk
}

function setup_node() {
    setup_common node
}

function setup_appium() {
    version=$1
    echo installing appium@${version}
    if [[ "$version" = "3.0.4" ]]; then
        npm install appium@${version} --registry http://10.32.52.100:8888/nexus/content/groups/npm-all
    else
        npm install appium@${version}
    fi 
}

function setup_chromedriver() {
    setup_common chromedriver
    chmod +x $local_bin/chromedriver
}

function setup_selenium_server_standalone() {
    setup_common selenium_server_standalone
}

function check_and_install() {
    tool_name=$1
    check_func=check_${tool_name}
    install_func=setup_${tool_name}

    printf "checking $tool_name..."
    $check_func && echo OK && return 0
    echo $tool_name not found, installing $tool_name...
    $install_func && echo $tool_name installed. && return 0
}

function gen_env() {
cat > env.sh << EOF
#!/bin/sh

export local_bin="$local_bin"
export platform="$platform"
export ANDROID_HOME="$ANDROID_HOME"
export PATH="$PATH"

EOF
}

function gen_start_appium() {
cat > start_appium.sh << "EOF"
#!/bin/sh

source ./common.sh

devices=./data/devices

function scan_dev() {
    rm -rf $devices && touch $devices
    if [[ $platform == 'mac' ]]; then
	# gather iOS device information
	dev_type=ios
	instruments -s devices 2>/dev/null |
	    awk "NR > 2 {print}"  |
	    grep -v "Apple TV" |
	    grep -v "Apple Watch" |
	    perl -n -e '/(.*) \((.*)\) \[(.*)\]\ ?(.*).*/ && print "mobile;DEVTYPE;".$2.";".$3.";PLATFORM;".$1.";".$4."\n"' |
	    sed -n -e "s/DEVTYPE/${dev_type}/gp" |
	    sed -n -e "s/PLATFORM/mac/gp" > $devices
    fi

    # gather android device information
    dev_id_list=$(adb devices -l | grep -v "List of devices attached" | tr -s ' ' | cut -d ' ' -f1)
    dev_id_list=$(adb devices -l | grep -v "List of devices attached" | tr -s ' ' | cut -d ' ' -f1)

    for dev_id in $dev_id_list
    do
	dev_name=$(adb -s $dev_id shell getprop ro.product.model)
	dev_version=$(adb -s $dev_id shell getprop ro.build.version.release)

	echo
	echo find android device:
	echo dev id: $dev_id
	echo dev name: $dev_name
	echo dev version: $dev_version
	echo

	echo "mobile;android;$dev_version;$dev_id;$platform;$dev_name;" >> $devices
    done

    # look for browsers installed
    jar_file=$local_bin/detector.jar
    if [[ $platform == 'windows' ]]; then
	jar_file=$(cygpath -w -a $jar_file)
    fi

    # java -jar "$jar_file" 2>/dev/null >> $devices
}

function gen_hub_conf() {
    declare -a dev_list
    local i=0
    while read -r line; do
	type=$(echo $line | cut -d";" -f 1)

	if [[ $type == 'mobile' ]]; then
	    platformName=$(echo $line | cut -d";" -f 2)
	    version=$(echo $line | cut -d";" -f 3)
	    udid=$(echo $line | cut -d";" -f 4)
	    _platform=$(echo $line | cut -d";" -f 5)
	    deviceName=$(echo $line | cut -d";" -f 6)
	    is_simulator=$(echo $line | cut -d";" -f 7)

	    if [[ -z $is_simulator ]]; then
		udid_tuple=",\"UDID\": \"$udid\""
	    else
		udid_tuple=
	    fi

	    dev=$(
cat << run_EOF
    {
	"deviceName": "$deviceName",
	"maxInstances": 1,
	"platform": "$_platform",
	"browserName": "",
	"version": "$version",
	"platformName": "$platformName"
	$udid_tuple
    }
run_EOF
)
	else  # browser
	    browserName=$(echo $line | cut -d";" -f 2)
	    version=$(echo $line | cut -d";" -f 3)
	    _platform=$(echo $line | cut -d";" -f 4)

	    dev=$(
cat << run_EOF
    {
	"browserName": "$browserName",
	"version": "$version",
	"platform": "$_platform",
	"maxInstances": 4
    }
run_EOF
)
	fi

	i=$((i+1))
	
	dev_list[$i]=$dev

    done < data/devices

    dev_list=$(printf ",%s" "${dev_list[@]}")
    dev_list=${dev_list:1}

    hub_conf=$(
cat << run_EOF
    {
        "registerCycle": 5000,
        "cleanUpCycle": 2000,
        "host": "APPIUM_HOST",
        "proxy": "org.openqa.grid.selenium.proxy.DefaultRemoteProxy",
        "maxSession": 1,
        "port": "APPIUM_PORT",
        "hubPort": HUB_PORT,
        "hubHost": "HUB_HOST",
        "url": "http://APPIUM_HOST:APPIUM_PORT/wd/hub",
        "register": true,
        "timeout": 30000
    }
run_EOF
)

cat > appium_config.tpl.json << run_EOF
{
    "configuration": $hub_conf,
    "capabilities": [$dev_list]
}
run_EOF

}

function run() {
    scan_dev
    gen_hub_conf
    select_hub
    select_local_ip

    appium_host=$local_ip
    appium_port=4723
    cat appium_config.tpl.json |
	sed -e "s/HUB_PORT/${hub_port}/g" |
	sed -e "s/HUB_HOST/${hub_host}/g" |
	sed -e "s/APPIUM_HOST/${appium_host}/g" | 
	sed -e "s/APPIUM_PORT/${appium_port}/g" |
	iconv -c -f utf-8 -t ascii |
	tr -d '\r' > appium_config.json

    appium --nodeconfig ./appium_config.json -p 4723
}

run

EOF

chmod +x start_appium.sh

}

function gen_start_selenium() {
cat > start_selenium.sh << "EOF"
#!/bin/sh

source ./common.sh
browsers=./data/browsers

function detect_browser() {
    jar_file=$local_bin/detector.jar
    if [[ $platform == 'windows' ]]; then
	jar_file=$(cygpath -w -a $jar_file)
    fi

    java -jar "$jar_file" > $browsers
}

function gen_hub_conf() {
    dev_list=()
    local i=0
    while read -r line; do
	browserName=$(echo $line | cut -d";" -f 2)
	version=$(echo $line | cut -d";" -f 3)
	_platform=$(echo $line | cut -d";" -f 4)

	dev=$(
cat << run_EOF
    {
	"browserName": "$browserName",
	"version": "$version",
	"platform": "$_platform",
	"maxInstances": 4
    }
run_EOF
)
	dev_list[$i]=$dev
	i=$((i+1))
    done < $browsers

    dev_list=$(printf ",%s" "${dev_list[@]}")
    dev_list=${dev_list:1}

    hub_conf=$(
cat << run_EOF
    {
        "registerCycle": 5000,
        "cleanUpCycle": 2000,
        "host": "SELENIUM_HOST",
        "proxy": "org.openqa.grid.selenium.proxy.DefaultRemoteProxy",
        "maxSession": 1,
        "port": "SELENIUM_PORT",
        "hubPort": HUB_PORT,
        "hubHost": "HUB_HOST",
        "url": "http://SELENIUM_HOST:SELENIUM_PORT/wd/hub",
        "register": true,
        "timeout": 30000
    }
run_EOF
)

cat > selenium_config.tpl.json << run_EOF
{
    "configuration": $hub_conf,
    "capabilities": [$dev_list]
}
run_EOF


}

function run() {
    detect_browser
    gen_hub_conf
    select_hub
    select_local_ip

    selenium_host=$local_ip
    selenium_port=4723
    cat selenium_config.tpl.json |
	sed -e "s/HUB_PORT/${hub_port}/g" |
	sed -e "s/HUB_HOST/${hub_host}/g" |
	sed -e "s/SELENIUM_HOST/${selenium_host}/g" | 
	sed -e "s/SELENIUM_PORT/${selenium_port}/g" |
	iconv -c -f utf-8 -t ascii |
	tr -d '\r' > selenium_config.json

    jar_file=$local_bin/selenium_server_standalone.jar
    if [[ $platform == 'windows' ]]; then
	jar_file=$(cygpath -w -a $jar_file)
    fi
    java -jar $jar_file -role node -nodeConfig selenium_config.json
}

run

EOF

chmod +x start_selenium.sh

}

function run() {
    echo platform: $platform

    gen_env
    gen_common && source ./common.sh
    while true; do
        echo please choose:
        echo "1. config enviroment for web tests."
        echo "2. config enviroment for mobile tests."
        read choice
        if [ $choice -ge 1 ] && [ $choice -le 2 ]; then
            echo you choose: $choice.
            break
        fi
    done

    if [[ $platform == 'mac' ]]; then
	if [ $choice -eq 2 ]; then
            check_xcode || die "Failed xcode not found!"
        fi
	check_and_install ios_tools || die "Failed setting up ios tools!"
    fi

    check_and_install java || die "Failed setting up java!"
    check_and_install android_sdk || die "Failed setting up android sdk!"
    check_and_install node || die "Failed setting up node!"
    if [ $choice -eq 2 ]; then
        check_and_install_appium || die "Failed setting up appium!"
    fi
    # check_and_install appium || die "Failed setting up appium!"
    check_and_install chromedriver || die "Failed setting up chromedriver!"
    check_and_install selenium_server_standalone || die "Failed setting up selenium!"

    if [ ! -f $local_bin/detector.jar ]; then
	curl $repo/detector.jar > $local_bin/detector.jar
    fi

    gen_start_appium
    gen_start_selenium
}

run

