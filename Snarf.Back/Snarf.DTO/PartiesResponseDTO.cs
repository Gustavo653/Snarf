namespace Snarf.DTO
{
    public class PartiesResponseDTO
    {
        public Guid Id { get; set; }
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public string EventType { get; set; }
        public string Title { get; set; }
        public string ImageUrl { get; set; }
        public string UserRole { get; set; }
    }
}
