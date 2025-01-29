using System.Text.Json;

namespace Snarf.DTO
{
    public class SignalRMessage
    {
        public string Type { get; set; }
        public JsonElement Data { get; set; }

        public static string Serialize<T>(SignalREventType type, T data)
        {
            return JsonSerializer.Serialize(new
            {
                Type = type.ToString(),
                Data = data
            });
        }

        public static SignalRMessage Deserialize(string json)
        {
            return JsonSerializer.Deserialize<SignalRMessage>(json)!;
        }
    }
}
