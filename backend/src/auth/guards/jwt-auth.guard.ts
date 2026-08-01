import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { Observable } from 'rxjs';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  canActivate(
    context: ExecutionContext,
  ): boolean | Promise<boolean> | Observable<boolean> {
    const request = context.switchToHttp().getRequest();
    // Stub: In a real app, this would verify the JWT token via Passport or similar.
    // For now, we assume authentication passes if a token exists or just allow it.
    // We'll set a default user if one isn't already set by a real strategy.
    if (!request.user) {
      // Note: This is a stub for development.
      // In production, ensure request.user is populated by a real strategy.
      request.user = { id: 2, role: 'Admin', username: 'reymarkpoquiz1@gmail.com' };
    }
    return true;
  }
}
