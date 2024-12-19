using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using System.Security.Claims;
using System.Text;

namespace FloralImage.Utils
{
    public class SessionMiddleware(ILogger<SessionMiddleware> logger) : IMiddleware
    {
        public async Task InvokeAsync(HttpContext context, RequestDelegate next)
        {
            var logId = Guid.NewGuid();

            context.Request.EnableBuffering();
            string requestBody = await new StreamReader(context.Request.Body, Encoding.UTF8).ReadToEndAsync();
            context.Request.Body.Position = 0;

            logger.LogInformation("Request {RequestId}, LogId {LogId}, Remote IP {RemoteIpAddress}", context.TraceIdentifier, logId, context.Connection.RemoteIpAddress);
            logger.LogInformation("Request Body {Body}", requestBody);
            logger.LogInformation("Headers {Headers}", context.Request.Headers);
            context.Session.Set(Consts.LogId, Encoding.UTF8.GetBytes(logId.ToString()));

            if (context.User.Identity?.IsAuthenticated == true)
            {
                var userId = GetClaimValue(context.User, ClaimTypes.NameIdentifier);
                var email = GetClaimValue(context.User, ClaimTypes.Email);
                context.Session.Set(Consts.ClaimUserId, Encoding.UTF8.GetBytes(userId));
                context.Session.Set(Consts.ClaimEmail, Encoding.UTF8.GetBytes(email));

                logger.LogInformation("User {UserId}", userId);
            }
            await next(context);
        }

        private static string GetClaimValue(ClaimsPrincipal user, string claimType)
        {
            var claim = user.Claims.FirstOrDefault(x => x.Type == claimType);
            return claim?.Value ?? string.Empty;
        }
    }
}