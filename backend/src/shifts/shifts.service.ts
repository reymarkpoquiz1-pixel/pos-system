import { Injectable, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Shift, ShiftStatus } from './entities/shift.entity';

@Injectable()
export class ShiftsService {
  constructor(
    @InjectRepository(Shift)
    private readonly shiftRepository: Repository<Shift>,
  ) {}

  async findActiveShift(userId: number): Promise<Shift | null> {
    return await this.shiftRepository.findOne({
      where: {
        user: { id: userId },
        status: ShiftStatus.OPEN,
      },
      relations: { branch: true },
    });
  }

  async openShift(userId: number, branchId: number, startingCash: number) {
    const activeShift = await this.findActiveShift(userId);
    if (activeShift) {
      throw new BadRequestException('User already has an active shift');
    }

    const shift = this.shiftRepository.create({
      user: { id: userId },
      branch: { id: branchId },
      startingCash,
      totalSales: 0,
      actualCash: 0,
      status: ShiftStatus.OPEN,
    });

    return await this.shiftRepository.save(shift);
  }

  async closeShift(shiftId: number, actualCash: number, _notes: string) {
    const shift = await this.shiftRepository.findOne({
      where: { id: shiftId },
      relations: { user: true },
    });

    if (!shift) {
      throw new BadRequestException('Shift not found');
    }

    if (shift.status === ShiftStatus.CLOSED) {
      throw new BadRequestException('Shift is already closed');
    }

    shift.actualCash = actualCash;
    shift.status = ShiftStatus.CLOSED;
    shift.endTime = new Date();
    // Entity doesn't have a 'notes' field, so we just ignore it for now or log it
    // If you need to store notes, add it to the Shift entity.

    return await this.shiftRepository.save(shift);
  }
}
