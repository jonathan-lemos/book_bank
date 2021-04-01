import {Component, EventEmitter, Input, OnInit, Output} from '@angular/core';

@Component({
  selector: 'app-button',
  templateUrl: './button.component.html',
  styleUrls: ['./button.component.sass']
})
export class ButtonComponent implements OnInit {
  @Input() text: string = "";
  @Output() click = new EventEmitter<void>();

  constructor() { }

  ngOnInit(): void {
  }

}
