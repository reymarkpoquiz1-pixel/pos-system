import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Customer } from './entities/customer.entity';
import { UserRole } from '../users/entities/user.entity';

@Injectable()
export class CustomersService {
  constructor(
    @InjectRepository(Customer)
    private readonly customerRepository: Repository<Customer>,
  ) {}

  async findAll() {
    return await this.customerRepository.find();
  }

  async findOne(id: number) {
    const customer = await this.customerRepository.findOne({ where: { id } });
    if (!customer) {
      throw new NotFoundException(`Customer with ID ${id} not found`);
    }
    return customer;
  }

  async create(data: any) {
    const customer = this.customerRepository.create(data);
    return await this.customerRepository.save(customer);
  }

  async update(id: number, data: any) {
    await this.customerRepository.update(id, data);
    return this.findOne(id);
  }

  async remove(id: number) {
    const customer = await this.findOne(id);
    await this.customerRepository.remove(customer);
    return { success: true };
  }

  async updatePoints(id: number, points: number) {
    const customer = await this.findOne(id);
    customer.points += points;
    return await this.customerRepository.save(customer);
  }
}
