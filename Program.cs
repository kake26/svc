using System;
using System.Diagnostics;
using System.IO;

namespace svc_csharp
{
    class Program
    {
        static int Main(string[] args)
        {
            if (args.Length == 0)
            {
                ShowHelp();
                return 0;
            }

            string command = args[0].ToLowerInvariant();
            string? target = args.Length > 1 ? args[1] : null;

            // Normalize short aliases
            command = command switch
            {
                "st"     => "status",
                "up"     => "start",
                "down"   => "stop",
                "rs"     => "restart",
                "en"     => "enable",
                "dis"    => "disable",
                _        => command
            };

            // Early exit for help
            if (command == "help" || command == "--help" || command == "-h")
            {
                ShowHelp();
                return 0;
            }

            string pm = DetectPackageManager();
            string init = DetectInitSystem();

            if (pm == "unknown")
            {
                Console.Error.WriteLine("Could not detect a supported package manager (apt/dnf/pacman).");
                return 1;
            }
            if (init == "unknown")
            {
                Console.Error.WriteLine("Could not detect init system (systemd or OpenRC).");
                return 1;
            }

            Console.WriteLine($"Using package manager: {pm}");
            Console.WriteLine($"Using init system: {init}");

            return command switch
            {
                "install"   => DoPackageInstall(pm, target),
                "uninstall" => DoPackageRemove(pm, target),
                "start"     => DoService("start",   target, init),
                "stop"      => DoService("stop",    target, init),
                "restart"   => DoService("restart", target, init),
                "status"    => DoService("status",  target, init),
                "enable"    => DoServiceEnableDisable("enable",  target, init),
                "disable"   => DoServiceEnableDisable("disable", target, init),
                "list"      => DoServiceList(init),
                _           => UnknownCommand(command),
            };
        }

        static string DetectPackageManager()
        {
            if (Environment.OSVersion.Platform != PlatformID.Unix)
                return "unknown";

            if (File.Exists("/usr/bin/apt") || File.Exists("/usr/bin/apt-get")) return "apt";
            if (File.Exists("/usr/bin/dnf"))                                    return "dnf";
            if (File.Exists("/usr/bin/pacman"))                                 return "pacman";

            return "unknown";
        }

        static string DetectInitSystem()
        {
            if (Environment.OSVersion.Platform != PlatformID.Unix)
                return "unknown";

            // systemd detection
            if (File.Exists("/run/systemd/system") || File.Exists("/usr/bin/systemctl"))
                return "systemd";

            // OpenRC detection
            if (File.Exists("/sbin/rc-service") || File.Exists("/usr/sbin/rc-service") ||
                File.Exists("/etc/init.d/rc") || Directory.Exists("/etc/init.d"))
                return "openrc";

            return "unknown";
        }

        static int DoPackageInstall(string pm, string? pkg)
        {
            if (string.IsNullOrWhiteSpace(pkg))
            {
                Console.WriteLine("Usage: svc install <package>");
                return 1;
            }

            string cmd = pm switch
            {
                "apt"    => $"apt install -y {pkg}",
                "dnf"    => $"dnf install -y {pkg}",
                "pacman" => $"pacman -S --noconfirm {pkg}",
                _        => throw new InvalidOperationException("Unexpected pm")
            };

            return RunWithSudo("bash", $"-c \"{cmd}\"");
        }

        static int DoPackageRemove(string pm, string? pkg)
        {
            if (string.IsNullOrWhiteSpace(pkg))
            {
                Console.WriteLine("Usage: svc uninstall <package>");
                return 1;
            }

            string cmd = pm switch
            {
                "apt"    => $"apt remove -y {pkg}",
                "dnf"    => $"dnf remove -y {pkg}",
                "pacman" => $"pacman -R --noconfirm {pkg}",
                _        => throw new InvalidOperationException("Unexpected pm")
            };

            return RunWithSudo("bash", $"-c \"{cmd}\"");
        }

        static int DoService(string action, string? service, string init)
        {
            if (string.IsNullOrWhiteSpace(service))
            {
                Console.WriteLine($"Usage: svc {action} <service>");
                return 1;
            }

            if (init == "systemd")
            {
                string args = action == "status"
                    ? $"status {service}"
                    : $"{action} {service}";
                return RunWithSudo("systemctl", args);
            }
            else // OpenRC
            {
                string args = $"{service} {action}";
                return RunWithSudo("rc-service", args);
            }
        }

        static int DoServiceEnableDisable(string action, string? service, string init)
        {
            if (string.IsNullOrWhiteSpace(service))
            {
                Console.WriteLine($"Usage: svc {action} <service>");
                return 1;
            }

            if (init == "systemd")
            {
                string args = $"{action} {service}";   // without --now
                // If you want auto-start/stop: $"{action} --now {service}"
                return RunWithSudo("systemctl", args);
            }
            else // OpenRC
            {
                string rcAction = action == "enable" ? "add" : "del";
                string args = $"{rcAction} {service} default";
                return RunWithSudo("rc-update", args);
            }
        }

        static int DoServiceList(string init)
        {
            if (init == "systemd")
                return Run("systemctl", "list-units --type=service --state=running");
            else // OpenRC
                return Run("rc-status", "--all");
        }

        static int UnknownCommand(string cmd)
        {
            Console.Error.WriteLine($"Unknown command: {cmd}");
            ShowHelp();
            return 1;
        }

        static void ShowHelp()
        {
            Console.WriteLine("svc - simple service & package control");
            Console.WriteLine("Usage: svc <command> [argument]");
            Console.WriteLine();
            Console.WriteLine("Service commands (works on systemd and OpenRC):");
            Console.WriteLine("  start <service>     (or up)");
            Console.WriteLine("  stop <service>      (or down)");
            Console.WriteLine("  restart <service>   (or rs)");
            Console.WriteLine("  status <service>    (or st)");
            Console.WriteLine("  enable <service>    (or en)   Enable at boot");
            Console.WriteLine("  disable <service>   (or dis)  Disable at boot");
            Console.WriteLine("  list                List running/all services");
            Console.WriteLine();
            Console.WriteLine("Package commands:");
            Console.WriteLine("  install <package>");
            Console.WriteLine("  uninstall <package>");
            Console.WriteLine();
            Console.WriteLine("Other:");
            Console.WriteLine("  help                Show this help");
            Console.WriteLine();
            Console.WriteLine("Auto-detects: apt/dnf/pacman and systemd/OpenRC");
        }

        static int Run(string exe, string arguments)
        {
            return RunProcess(exe, arguments, useSudo: false);
        }

        static int RunWithSudo(string exe, string arguments)
        {
            return RunProcess(exe, arguments, useSudo: true);
        }

        static int RunProcess(string exe, string arguments, bool useSudo)
        {
            string finalExe = exe;
            string finalArgs = arguments;

            if (useSudo && !IsRoot())
            {
                finalExe = "sudo";
                finalArgs = $"{exe} {arguments}";
            }

            Console.WriteLine($"→ Running: {finalExe} {finalArgs}");

            var psi = new ProcessStartInfo
            {
                FileName               = finalExe,
                Arguments              = finalArgs,
                RedirectStandardOutput = true,
                RedirectStandardError  = true,
                UseShellExecute        = false,
                CreateNoWindow         = true
            };

            try
            {
                using var p = Process.Start(psi)!;
                string stdout = p.StandardOutput.ReadToEnd();
                string stderr = p.StandardError.ReadToEnd();
                p.WaitForExit();

                if (!string.IsNullOrWhiteSpace(stdout)) Console.WriteLine(stdout.TrimEnd());
                if (!string.IsNullOrWhiteSpace(stderr))
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.Error.WriteLine(stderr.TrimEnd());
                    Console.ResetColor();
                }

                return p.ExitCode;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Failed to run command: {ex.Message}");
                return 127;
            }
        }

        static bool IsRoot()
        {
            return Environment.UserName == "root" ||
                   Environment.GetEnvironmentVariable("SUDO_USER") != null;
        }
    }
}