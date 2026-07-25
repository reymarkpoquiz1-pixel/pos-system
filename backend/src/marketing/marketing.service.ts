import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Promo } from './entities/promo.entity';
import { Voucher } from './entities/voucher.entity';

@Injectable()
export class MarketingService {
  constructor(
    @InjectRepository(Promo)
    private readonly promoRepository: Repository<Promo>,
    @InjectRepository(Voucher)
    private readonly voucherRepository: Repository<Voucher>,
  ) {}

  async getAllPromos() {
    return await this.promoRepository.find();
  }

  async getAllVouchers() {
    return await this.voucherRepository.find();
  }
}
