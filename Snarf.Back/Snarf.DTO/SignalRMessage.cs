using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

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
