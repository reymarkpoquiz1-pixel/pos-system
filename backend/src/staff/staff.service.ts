import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource, Not } from 'typeorm';
import { Staff, Gender } from './entities/staff.entity';
import { User, UserRole } from '../users/entities/user.entity';
import { ActivityLogsService } from '../activity-logs/activity-logs.service';
import * as bcrypt from 'bcrypt';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class StaffService {
  constructor(
    @InjectRepository(Staff)
    private staffRepository: Repository<Staff>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private activityLogsService: ActivityLogsService,
    private dataSource: DataSource,
  ) {}

  async getEmployees() {
    const users = await this.userRepository.find({
      where: { role: Not(UserRole.USER) },
      relations: { staff: true },
    });

    return users.map((u) => ({
      user_id: u.id,
      username: u.username,
      email: u.email,
      role: u.role,
      status: u.status,
      first_name: u.staff?.firstName || '',
      last_name: u.staff?.lastName || '',
      profile_image: u.staff?.profileImage || null,
      terminal_id: u.staff?.terminalId || '0',
      created_at: u.createdAt,
    }));
  }

  async updateStaff(data: any, ip: string) {
    return await this.dataSource.transaction(async (manager) => {
      const {
        user_id,
        username,
        role,
        password,
        first_name,
        last_name,
        gender,
        terminal_id,
        profile_image_base64,
        admin_id,
      } = data;

      const user = await manager.findOne(User, {
        where: { id: user_id },
        relations: { staff: true },
      });
      if (!user) throw new NotFoundException('User not found');

      // Update User
      if (username) user.username = username;
      if (role) user.role = role as UserRole;
      if (password) {
        user.password = await bcrypt.hash(password, 10);
      }
      await manager.save(user);

      // Update Staff
      let staff = user.staff;
      if (!staff) {
        staff = manager.create(Staff, { user });
      }

      if (first_name) staff.firstName = first_name;
      if (last_name) staff.lastName = last_name;
      if (gender) staff.gender = gender as Gender;
      if (terminal_id) staff.terminalId = terminal_id;

      // Handle Image
      if (profile_image_base64) {
        const fileName = `staff_${user_id}_${Date.now()}.png`;
        const uploadDir = path.join(process.cwd(), 'uploads');
        if (!fs.existsSync(uploadDir)) {
          fs.mkdirSync(uploadDir, { recursive: true });
        }
        const filePath = path.join(uploadDir, fileName);
        const base64Data = profile_image_base64.replace(
          /^data:image\/\w+;base64,/,
          '',
        );
        fs.writeFileSync(filePath, Buffer.from(base64Data, 'base64'));
        staff.profileImage = `uploads/${fileName}`;
      }

      await manager.save(staff);

      await this.activityLogsService.log(
        admin_id,
        'UPDATE_STAFF',
        `Updated staff member: ${user.username}`,
        ip,
      );

      return { success: true, message: 'Staff updated successfully' };
    });
  }

  async deleteStaff(userId: number, adminId: number, ip: string) {
    return await this.dataSource.transaction(async (manager) => {
      const user = await manager.findOne(User, {
        where: { id: userId },
        relations: { staff: true },
      });
      if (!user) throw new NotFoundException('User not found');

      // Soft delete by setting role to User and disabling or similar?
      // Requirement says "Hard or soft delete staff account (to match original intention)".
      // Previous logic might have just deleted it. Let's do a hard delete if it's an employee account.

      const username = user.username;

      if (user.staff) {
        await manager.remove(user.staff);
      }
      await manager.remove(user);

      await this.activityLogsService.log(
        adminId,
        'DELETE_STAFF',
        `Deleted staff member: ${username}`,
        ip,
      );

      return { success: true, message: 'Staff deleted successfully' };
    });
  }
}
