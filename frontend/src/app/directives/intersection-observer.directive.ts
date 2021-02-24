import {Directive, ElementRef, EventEmitter, OnInit, Output} from '@angular/core';

@Directive({
  selector: '[appIntersectionObserver]'
})
export class IntersectionObserverDirective implements OnInit {
  @Output() change = new EventEmitter<boolean>();

  observer: IntersectionObserver;

  constructor(private el: ElementRef) {
  }

  ngOnInit() {
    this.observer = new IntersectionObserver(e => {
      this.change.emit(e[0].intersectionRatio > 0);
    });
    this.observer.observe(this.el.nativeElement);
  }
}
