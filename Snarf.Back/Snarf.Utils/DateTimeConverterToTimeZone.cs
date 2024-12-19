using System.Text.Json;
using System.Text.Json.Serialization;

namespace Snarf.Utils
{
    public class DateTimeConverterToTimeZone(string timeZoneId) : JsonConverter<DateTime>
    {
        private readonly TimeZoneInfo _timeZone = TimeZoneInfo.FindSystemTimeZoneById(timeZoneId);

        public override DateTime Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            return reader.GetDateTime();
        }

        public override void Write(Utf8JsonWriter writer, DateTime value, JsonSerializerOptions options)
        {
            var localDateTime = TimeZoneInfo.ConvertTimeFromUtc(value, _timeZone);
            writer.WriteStringValue(localDateTime.ToString("o")); // ISO 8601
        }
    }
}
