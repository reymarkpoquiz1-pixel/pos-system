import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Supplier } from './entities/supplier.entity';

@Injectable()
export class SuppliersService {
  constructor(
    @InjectRepository(Supplier)
    private readonly supplierRepository: Repository<Supplier>,
  ) {}

  async findAll() {
    return this.supplierRepository.find();
  }

  async create(data: any) {
    const supplier = this.supplierRepository.create(data);
    return this.supplierRepository.save(supplier);
  }
}
