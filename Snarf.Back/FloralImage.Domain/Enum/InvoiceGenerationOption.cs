using System.ComponentModel;

namespace FloralImage.Domain.Enum
{
    public enum InvoiceGenerationOption
    {
        [Description("Apenas Fatura")]
        InvoiceOnly,
        [Description("Fatura e Boleto")]
        InvoiceAndBankSlip
    }
}
