import { Injectable, OnModuleInit, ConflictException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { User, UserRole } from './entities/user.entity';
import { Staff } from '../staff/entities/staff.entity';
import { Customer } from '../customers/entities/customer.entity';
import { CloudinaryService } from '../cloudinary/cloudinary.service';
import * as bcrypt from 'bcrypt';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class UsersService implements OnModuleInit {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
    @InjectRepository(Staff)
    private staffRepository: Repository<Staff>,
    private cloudinaryService: CloudinaryService,
    private dataSource: DataSource,
  ) {}

  async onModuleInit() {
    await this.seedAdmin();
  }

  async seedAdmin() {
    const admin = await this.findByUsername('admin');
    if (!admin) {
      console.log('Seeding default admin user...');
      await this.create({
        username: 'admin',
        password: 'password123',
        role: UserRole.ADMIN,
      });
    }
  }

  async findByUsername(username: string): Promise<User | null> {
    return this.usersRepository.findOne({
      where: { username },
      relations: { staff: true },
    });
  }

  async create(userData: Partial<User>): Promise<User> {
    const hashedPassword = await bcrypt.hash(userData.password, 10);
    const user = this.usersRepository.create({
      ...userData,
      password: hashedPassword,
    });
    return this.usersRepository.save(user);
  }

  async register(registrationDto: any) {
    const existingUser = await this.findByUsername(registrationDto.username);
    if (existingUser) {
      throw new ConflictException('Username already exists');
    }

    const hashedPassword = await bcrypt.hash(registrationDto.password, 10);

    return await this.dataSource.transaction(async (manager) => {
      // Determine name and email for the profile
      const fullName =
        registrationDto.name ||
        (registrationDto.first_name && registrationDto.last_name
          ? `${registrationDto.first_name} ${registrationDto.last_name}`
          : registrationDto.username);

      const userEmail =
        registrationDto.email ||
        (registrationDto.username.includes('@')
          ? registrationDto.username
          : null);

      const user = manager.create(User, {
        username: registrationDto.username,
        password: hashedPassword,
        role: UserRole.USER,
        email: userEmail,
      });
      const savedUser = await manager.save(user);

      const customer = manager.create(Customer, {
        user: savedUser,
        name: fullName,
        email: userEmail,
        phone: registrationDto.phone,
      });
      await manager.save(customer);

      return { success: true, message: 'User account created successfully!' };
    });
  }

  async registerStaff(data: any, adminId?: number) {
    const {
      username,
      password,
      first_name,
      last_name,
      name, // New field for Full Name
      gender,
      terminal_id,
      role,
      image,
      email,
    } = data;

    const existingUser = await this.findByUsername(username);
    if (existingUser) {
      throw new ConflictException('Username already exists');
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    return await this.dataSource.transaction(async (manager) => {
      // 1. Determine names
      let finalFirstName = first_name;
      let finalLastName = last_name;

      if (name && !first_name && !last_name) {
        const nameParts = name.trim().split(' ');
        finalFirstName = nameParts[0];
        finalLastName = nameParts.slice(1).join(' ') || ' ';
      }

      // 2. Determine email
      const userEmail = email || (username.includes('@') ? username : null);

      // 3. Create User
      const user = manager.create(User, {
        username,
        password: hashedPassword,
        role: (role as UserRole) || UserRole.STAFF,
        email: userEmail,
      });
      const savedUser = await manager.save(User, user);

      // 4. Handle Profile Image (Cloudinary)
      let profileImage: string | undefined = undefined;
      if (image && image.toString().length > 0) {
        try {
          const uploadRes = await this.cloudinaryService.uploadBase64(
            image,
            'staff_profiles',
          );
          profileImage = uploadRes.secure_url;
        } catch (e) {
          console.error('Image upload failed:', e);
        }
      }

      // 5. Create Staff Info
      const staff = manager.create(Staff, {
        user: savedUser,
        firstName: finalFirstName || ' ',
        lastName: finalLastName || ' ',
        gender: gender || 'Male',
        terminalId: terminal_id || '0',
        profileImage: profileImage,
        addedByAdminId: adminId, // Fixed mapping to match entity
      } as any);
      await manager.save(Staff, staff);

      return { success: true, message: 'Staff account created successfully!' };
    });
  }
}
