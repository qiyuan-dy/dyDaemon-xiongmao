// ============================================================================
// 抖音 39.5 版本验证脚本
// 用 Cycript 或 Frida 在设备上运行，验证类和方法是否存在
// ============================================================================

/*
=== Cycript 验证命令 ===

安装 cycript 后，在终端运行：
cycript -p Aweme

然后粘贴以下代码验证：
*/

// 1. 检查 AWENetworkService 是否存在
if (NSClassFromString(@"AWENetworkService")) {
    console.log("✅ AWENetworkService 存在");
    var service = [NSClassFromString(@"AWENetworkService") sharedService];
    console.log("   单例:", service);
    console.log("   方法数:", class_copyMethodList(object_getClass(service), NULL));
} else {
    console.log("❌ AWENetworkService 不存在");
}

// 2. 检查 TTNetworkManager
if (NSClassFromString(@"TTNetworkManager")) {
    console.log("✅ TTNetworkManager 存在");
} else {
    console.log("❌ TTNetworkManager 不存在");
}

// 3. 列出所有包含 Network 的类
var classes = [];
var count = objc_getClassList(NULL, 0);
var allClasses = malloc(count * sizeof(Class));
objc_getClassList(allClasses, count);
for (var i = 0; i < count; i++) {
    var cls = allClasses[i];
    var name = NSStringFromClass(cls);
    if (name && [name containsString:@"Network"]) {
        classes.push(name);
    }
}
console.log("\n所有 Network 相关类（共" + classes.length + "个）:");
classes.sort().forEach(function(c) { console.log("  " + c); });

// 4. 检查 AWEUserManager
if (NSClassFromString(@"AWEUserManager")) {
    console.log("\n✅ AWEUserManager 存在");
    var mgr = [NSClassFromString(@"AWEUserManager") sharedManager];
    console.log("   currentUserID:", [mgr currentUserID]);
    console.log("   currentSecUserID:", [mgr currentSecUserID]);
}

// 5. 检查点赞相关方法
if (NSClassFromString(@"AWEAwemeManager")) {
    console.log("\n✅ AWEAwemeManager 存在");
    var mgr = [NSClassFromString(@"AWEAwemeManager") sharedManager];
    // 打印所有包含 digg/like/praise 的方法
    var methodCount = 0;
    var methods = class_copyMethodList(object_getClass(mgr), &methodCount);
    console.log("   方法总数:", methodCount);
    for (var i = 0; i < methodCount; i++) {
        var sel = method_getName(methods[i]);
        var name = NSStringFromSelector(sel);
        if ([name.lowercaseString containsString:@"digg"] || 
            [name.lowercaseString containsString:@"like"] ||
            [name.lowercaseString containsString:@"praise"]) {
            console.log("   点赞相关方法:", name);
        }
    }
}

/*
=== Frida 验证命令 ===

frida -U -f com.ss.iphone.ugc.Aweme --no-pause -l verify.js

verify.js 内容：
*/

if (false) { // 仅供参考，不执行
    const { NSString } = ObjC.classes;

    // 列出所有含 Network 的类
    console.log("\n=== 网络相关类 ===");
    const classes = ObjC.classes;
    for (const className of Object.keys(classes).sort()) {
        if (className.includes("Network") || className.includes("network")) {
            console.log("  " + className);
        }
    }

    // 检查 AWENetworkService 的方法
    if (ObjC.classes.AWENetworkService) {
        console.log("\n=== AWENetworkService 方法 ===");
        const methods = ObjC.classes.AWENetworkService.$ownMethods;
        methods.filter(m => m.toLowerCase().includes("post") || m.toLowerCase().includes("request"))
               .forEach(m => console.log("  " + m));
    }
}
