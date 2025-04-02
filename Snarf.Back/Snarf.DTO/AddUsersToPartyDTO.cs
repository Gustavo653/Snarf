using System.ComponentModel.DataAnnotations;

namespace Snarf.DTO
{
    public class AddUsersToPartyDTO
    {
        [Required(ErrorMessage = "A lista de usuários é obrigatória.")]
        [MinLength(1, ErrorMessage = "É necessário fornecer pelo menos um ID de usuário.")]
        public List<string> UserIds { get; set; }
    }
}
