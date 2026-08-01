import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UsersService } from '../users/users.service';
import { SettingsService } from '../settings/settings.service';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
    private settingsService: SettingsService,
  ) {}

  async login(loginDto: any) {
    const user = await this.usersService.findByUsernameOrEmail(loginDto.username);
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const isPasswordMatching = await bcrypt.compare(
      loginDto.password,
      user.password,
    );

    if (!isPasswordMatching) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const storeSettings = await this.settingsService.getStoreSettings();

    const payload = { username: user.username, sub: user.id, role: user.role };

    // Map to match the expected response structure
    const userData = {
      id: user.id,
      username: user.username,
      email: user.email,
      role: user.role,
      status: user.status,
      is_2fa_enabled: user.is2faEnabled ? 1 : 0,
      first_name: user.staff?.firstName || '',
      last_name: user.staff?.lastName || '',
      profile_image: user.staff?.profileImage || null,
      terminal_id: user.staff?.terminalId || '0',
    };

    return {
      success: true,
      message: 'Login successful!',
      token: this.jwtService.sign(payload),
      access_token: this.jwtService.sign(payload), // Support both names
      refresh_token: 'dummy-refresh-token',
      store_name: storeSettings?.store_name || 'My POS Store',
      logo_url: storeSettings?.logo_url || null,
      user: userData,
    };
  }
}
