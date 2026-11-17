const commandOutput = document.querySelector("#commandOutput");
const viewTitle = document.querySelector("#viewTitle");
const toast = document.querySelector("#toast");

const commands = {
  apk: [
    {
      id: "decompile",
      label: "Decompile",
      hint: "Decode APK into workspace",
      build: () => ps("apk", "decompile", [val("apkPath"), val("apkOutput")])
    },
    {
      id: "recompile",
      label: "Recompile",
      hint: "Build decoded project",
      build: () => ps("apk", "recompile", [val("apkPath")])
    },
    {
      id: "sign",
      label: "Sign",
      hint: "Sign rebuilt APK",
      build: () => ps("apk", "sign", [val("apkPath"), val("apkOutput")])
    },
    {
      id: "zipalign",
      label: "Zipalign",
      hint: "Optimize APK alignment",
      build: () => ps("apk", "zipalign", [val("apkPath"), val("apkOutput")])
    },
    {
      id: "install",
      label: "Install",
      hint: "ADB install -r",
      build: () => ps("apk", "install", [val("apkPath")])
    },
    {
      id: "uninstall",
      label: "Uninstall",
      hint: "Remove package id",
      build: () => ps("apk", "uninstall", [val("apkPath")])
    }
  ],
  device: [
    {
      id: "list",
      label: "List devices",
      hint: "adb devices -l",
      build: () => ps("device", "list")
    },
    {
      id: "check",
      label: "Check",
      hint: "Get device state",
      build: () => ps("device", "check")
    },
    {
      id: "shell",
      label: "Shell",
      hint: "Open ADB shell",
      build: () => ps("device", "shell")
    },
    {
      id: "reboot",
      label: "Reboot",
      hint: "Reboot system",
      build: () => ps("device", "reboot")
    },
    {
      id: "recovery",
      label: "Recovery",
      hint: "Reboot recovery",
      build: () => ps("device", "recovery")
    },
    {
      id: "bootloader",
      label: "Bootloader",
      hint: "Reboot bootloader",
      build: () => ps("device", "bootloader")
    },
    {
      id: "connect",
      label: "Connect",
      hint: "Wireless ADB target",
      build: () => ps("device", "connect", [val("deviceTarget")])
    },
    {
      id: "disconnect",
      label: "Disconnect",
      hint: "Wireless ADB target",
      build: () => ps("device", "disconnect", [val("deviceTarget")])
    },
    {
      id: "logcat",
      label: "Logcat",
      hint: "Last 300 lines",
      build: () => ps("device", "logcat")
    }
  ],
  rom: [
    {
      id: "list-apks",
      label: "List APKs",
      hint: "Scan ROM workspace",
      build: () => ps("rom", "list-apks", [val("romPath")])
    },
    {
      id: "add-apk",
      label: "Add APK",
      hint: "Copy APK into system app",
      build: () => ps("rom", "add-apk", [val("romAsset"), val("romPath")])
    },
    {
      id: "bootanimation",
      label: "Bootanimation",
      hint: "Replace bootanimation.zip",
      build: () => ps("rom", "bootanimation", [val("romAsset"), val("romPath")])
    },
    {
      id: "makezip",
      label: "Make ZIP",
      hint: "Package workspace",
      build: () => ps("rom", "makezip", [val("romPath"), val("romAsset")])
    }
  ],
  files: [
    {
      id: "hash",
      label: "Hash",
      hint: "MD5/SHA1/SHA256",
      build: () => ps("files", "hash", [val("filePath")])
    },
    {
      id: "pull-documents",
      label: "Pull documents",
      hint: "ADB pull Documents",
      build: () => ps("files", "pull-documents", [val("filePath")])
    },
    {
      id: "push",
      label: "Push file",
      hint: "ADB push to /sdcard/Download",
      build: () => ps("files", "push-download", [val("filePath")])
    }
  ]
};

function val(id) {
  return document.querySelector(`#${id}`)?.value.trim() || "";
}

function quote(value) {
  if (!value) return "\"\"";
  return `"${value.replaceAll("\"", "`\"")}"`;
}

function ps(section, command, args = []) {
  const argText = args.length ? ` -Args ${args.map(quote).join(",")}` : "";
  return `.\\scripts\\autodev.ps1 -Section ${section} -Command ${command}${argText}`;
}

function setCommand(text) {
  commandOutput.textContent = text;
}

function showToast(message) {
  toast.textContent = message;
  toast.classList.add("visible");
  window.setTimeout(() => toast.classList.remove("visible"), 1800);
}

function activateView(id) {
  document.querySelectorAll(".view").forEach((view) => view.classList.toggle("active", view.id === id));
  document.querySelectorAll(".nav-item").forEach((item) => item.classList.toggle("active", item.dataset.view === id));
  viewTitle.textContent = document.querySelector(`[data-view="${id}"]`)?.textContent || "Dashboard";
}

function renderActions() {
  document.querySelectorAll(".action-grid").forEach((grid) => {
    const section = grid.dataset.section;
    grid.innerHTML = "";
    commands[section].forEach((action) => {
      const button = document.createElement("button");
      button.className = "action-button";
      button.type = "button";
      button.innerHTML = `<strong>${action.label}</strong><span>${action.hint}</span>`;
      button.addEventListener("click", () => setCommand(action.build()));
      grid.append(button);
    });
  });
}

async function copyCurrentCommand() {
  try {
    await navigator.clipboard.writeText(commandOutput.textContent);
  } catch {
    const scratch = document.createElement("textarea");
    scratch.value = commandOutput.textContent;
    scratch.setAttribute("readonly", "");
    scratch.style.position = "fixed";
    scratch.style.opacity = "0";
    document.body.append(scratch);
    scratch.select();
    document.execCommand("copy");
    scratch.remove();
  }
  showToast("Command copied");
}

function loadSettings() {
  const saved = JSON.parse(localStorage.getItem("autodev-reborn") || "{}");
  Object.entries(saved).forEach(([id, value]) => {
    const input = document.querySelector(`#${id}`);
    if (input) input.value = value;
  });
  document.documentElement.classList.toggle("light", saved.theme === "light");
}

function saveSettings() {
  const settings = {
    toolHome: val("toolHome"),
    projectHome: val("projectHome"),
    theme: document.documentElement.classList.contains("light") ? "light" : "dark"
  };
  localStorage.setItem("autodev-reborn", JSON.stringify(settings));
  showToast("Settings saved");
}

document.querySelectorAll(".nav-item").forEach((item) => {
  item.addEventListener("click", () => activateView(item.dataset.view));
});

document.querySelectorAll("[data-jump]").forEach((card) => {
  card.addEventListener("click", () => activateView(card.dataset.jump));
});

document.querySelector("#copyCommand").addEventListener("click", copyCurrentCommand);
document.querySelector("#copyDepsCommand").addEventListener("click", () => {
  setCommand(".\\scripts\\autodev.ps1 -Section deps -Command scan");
  copyCurrentCommand();
});

document.querySelector("#themeToggle").addEventListener("click", () => {
  document.documentElement.classList.toggle("light");
  saveSettings();
});

document.querySelector("#saveSettings").addEventListener("click", saveSettings);

renderActions();
loadSettings();
setCommand(".\\scripts\\autodev.ps1 -Section deps -Command scan");
