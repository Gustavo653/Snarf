using FloralImage.Domain.Shared;

namespace FloralImage.Domain.Location;

public class State : BasicEntity
{
    public required int Code { get; set; }
    public required string Abbreviation { get; set; }
    public IList<City>? Cities { get; set; }
}