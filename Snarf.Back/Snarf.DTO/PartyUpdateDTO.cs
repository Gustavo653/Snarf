namespace Snarf.DTO
{
    public class PartyUpdateDTO
    {
        public string Title { get; set; }
        public string Description { get; set; }
        public string Location { get; set; }
        public string Instructions { get; set; }

        public DateTime StartDate { get; set; }
        public int Duration { get; set; }
    }
}
