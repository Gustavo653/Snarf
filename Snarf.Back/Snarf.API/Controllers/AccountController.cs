using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Snarf.DTO;
using Snarf.Infrastructure.Service;
using System.Security.Claims;

namespace Snarf.API.Controllers
{
    public class AccountController(IAccountService accountService) : BaseController
    {
        [HttpPost("Login")]
        [AllowAnonymous]
        public async Task<IActionResult> Login([FromBody] UserLoginDTO userLogin)
        {
            var user = await accountService.Login(userLogin);
            return StatusCode(user.Code, user);
        }

        [HttpGet("GetUser/{requestedUserId:guid}")]
        public async Task<IActionResult> GetUser([FromRoute] Guid requestedUserId)
        {
            var userId = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);
            var user = await accountService.GetCurrent(requestedUserId, userId == requestedUserId);
            return StatusCode(user.Code, user);
        }

        [HttpPost("BlockUser")]
        public async Task<IActionResult> BlockUser([FromQuery] Guid blockedUserId)
        {
            var blockerUserId = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);
            var user = await accountService.BlockUser(blockerUserId, blockedUserId);
            return StatusCode(user.Code, user);
        }

        [HttpPost("UnblockUser")]
        public async Task<IActionResult> UnblockUser([FromQuery] Guid blockedUserId)
        {
            var blockerUserId = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);
            var user = await accountService.UnblockUser(blockerUserId, blockedUserId);
            return StatusCode(user.Code, user);
        }

        [HttpPost("ReportUserPublicMessage")]
        public async Task<IActionResult> ReportUserPublicMessage([FromQuery] Guid messageId)
        {
            var user = await accountService.ReportUserPublicMessage(messageId);
            return StatusCode(user.Code, user);
        }

        [HttpPut("{id:guid}")]
        public async Task<IActionResult> UpdateUser([FromRoute] Guid id, [FromBody] UserDTO userDTO)
        {
            id = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);
            var user = await accountService.UpdateUser(id, userDTO);
            return StatusCode(user.Code, user);
        }

        [HttpDelete("{id:guid}")]
        public async Task<IActionResult> RemoveUser([FromRoute] Guid id)
        {
            id = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);
            var user = await accountService.RemoveUser(id);
            return StatusCode(user.Code, user);
        }

        [HttpPost("")]
        [AllowAnonymous]
        public async Task<IActionResult> CreateUser([FromBody] UserDTO userDTO)
        {
            var user = await accountService.CreateUser(userDTO);
            return StatusCode(user.Code, user);
        }

        [HttpPost("RequestResetPassword")]
        [AllowAnonymous]
        public async Task<IActionResult> RequestResetPassword([FromBody] string email)
        {
            var user = await accountService.RequestResetPassword(email);
            return StatusCode(user.Code, user);
        }

        [HttpPost("ResetPassword")]
        [AllowAnonymous]
        public async Task<IActionResult> ResetPassword([FromBody] UserEmailDTO userEmailDTO)
        {
            var user = await accountService.ResetPassword(userEmailDTO);
            return StatusCode(user.Code, user);
        }
    }
}