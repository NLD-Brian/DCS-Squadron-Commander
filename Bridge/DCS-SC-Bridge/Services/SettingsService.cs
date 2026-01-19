using System;
using System.IO;
using System.Text.Json;
using DCS_SC_Bridge.Models;

namespace DCS_SC_Bridge.Services
{
    public class SettingsService
    {
        private const string SettingsFileName = "appsettings.json";
        private readonly string _settingsPath;

        public SettingsService()
        {
            var appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            var appFolder = Path.Combine(appDataPath, "DCS-SC-Bridge");
            
            if (!Directory.Exists(appFolder))
                Directory.CreateDirectory(appFolder);
            
            _settingsPath = Path.Combine(appFolder, SettingsFileName);
        }

        public AppSettings Load()
        {
            try
            {
                if (File.Exists(_settingsPath))
                {
                    var json = File.ReadAllText(_settingsPath);
                    return JsonSerializer.Deserialize<AppSettings>(json) ?? new AppSettings();
                }
            }
            catch
            {
                // If loading fails, return defaults
            }

            return new AppSettings();
        }

        public void Save(AppSettings settings)
        {
            try
            {
                var json = JsonSerializer.Serialize(settings, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(_settingsPath, json);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Failed to save settings", ex);
            }
        }
    }
}
