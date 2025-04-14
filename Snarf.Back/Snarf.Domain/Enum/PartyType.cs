using System.ComponentModel;

namespace Snarf.Domain.Enum
{
    public enum PartyType
    {
        [Description("Orgia")]
        Orgy = 0,
        [Description("Bomba e Despejo")]
        PumpDump = 1,
        [Description("Masturbação Coletiva")]
        CollectiveMasturbation = 2,
        [Description("Grupo de Bukkake")]
        BukkakeGroup = 3,
        [Description("Grupo Fetiche")]
        FetishGroup = 4,
        [Description("Evento Especial")]
        SpecialEvent = 5
    }
}
