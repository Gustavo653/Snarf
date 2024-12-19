using System.ComponentModel;

namespace FloralImage.Domain.Enum
{
    public enum BillingStatus
    {
        [Description("Ativo")]
        Active,
        [Description("Inativo")]
        Inactive,
        [Description("Pausado")]
        Paused
    }
}
