namespace DCS_SC_Bridge.Models
{
    public class AppSettings
    {
        public string ListenerIp { get; set; } = "127.0.0.1";
        public int ListenerPort { get; set; } = 10310;
        public string ApiUrl { get; set; } = "";
        public string ApiToken { get; set; } = "";
    }
}
