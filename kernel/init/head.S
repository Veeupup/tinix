/* head.S - kernel entry */

#define     PAGE_OFFSET     0xC0000000
#define     PAGE_DIR        0x00100000              /* PDE */
#define     PAGE_PTE_1      0x00101000              /* PTE 1 */
#define     KERNEL_CS       0x08
#define     KERNEL_DS       0x10
#define     USER_CS         0x18
#define     USER_DS         0x23

.text
.globl  start, _gdt_pdesc, _idt_pdesc, _idt, _gdt
start:
    movl    $0x90000, %esp                          /* ����esp */
    call    init_page                               /* ��ʼ��ҳ�� */
    call    init_gdt                                /* �����ҳ�����gdt */
    
    call    init_8259a                              /* ��ʼ���жϿ����� */
    call    init_idt                                /* ��ʼ��������idt */
    call    _k_main                                 /* C�����ں����,�ټ�at&t���! */
init_gdt:
    lgdtl   (_gdt_pdesc)
    movw    $KERNEL_DS, %ax                         /* ����gdt ���¶μĴ��� */
    movw    %ax, %fs
    movw    %ax, %ds
    movw    %ax, %es
    movw    %ax, %ss
    movw    %ax, %gs
    popl    %eax
    pushl   $KERNEL_CS
    pushl   %eax
    retf
/*****************************************************************/
/*                                                               */
/*                 ��ʼ��ҳĿ¼ҳ��                              */
/*                                                               */
/*****************************************************************/
init_page:
    xorl    %ecx, %ecx
    movl    $PAGE_DIR, %edi
clear_pde:
    movl    %ecx, (%edi)                            /* ���ҳĿ¼ */
    addl    $4, %edi
    cmpl    $(PAGE_DIR + 0x1000), %edi
    jne     clear_pde
    
    movl    $PAGE_DIR, %edi                         /* ��ʼ��pde */
                                                    /* �����Ե�ַ0~0x400000��0xC0000000~0xC0400000 */
                                                    /* ӳ�䵽��ͬ��������ַ0~4m, ��ֹ����ҳ���쳣  */
    movl    $(PAGE_PTE_1 + 3), (%edi)               /* PDE ��1�� 4m, ��1��ʾ�ڴ���ӳ��  */
    addl    $0xc00, %edi
    movl    $(PAGE_PTE_1 + 3), (%edi)               /* PDE ��0xc00�� 4m, ��1��ʾ�ڴ���ӳ�� */   
    
    movl    $1, %ecx
    movl    $PAGE_PTE_1, %edi
init_pte:
    movl    %ecx, (%edi)                            /* ����ҳ��1 */
    addl    $4, %edi
    addl    $0x1000, %ecx
    cmpl    $(PAGE_PTE_1 + 0x1000), %edi
    jne     init_pte
    
    movl    $PAGE_DIR, %eax                         /* ����ҳ */
    movl    %eax, %cr3
    movl    %cr0, %eax
    or      $0x80000000, %eax
    movl    %eax, %cr0
    
    addl    $PAGE_OFFSET, %esp                       /* ����esp�ͷ��ص�ַ */
    popl    %eax
    addl    $PAGE_OFFSET, %eax
    pushl   %eax
    ret
    
/*****************************************************************/
/*                                                               */
/*                 ���³�ʼ��8259a�жϿ���                       */
/*                                                               */
/*****************************************************************/
init_8259a:
    movb  $0x11, %al                                /* ���³�ʼ��8259a�жϿ����� */
    out   %al, $0x20
    call  _delay
    out   %al, $0xA0
    call  _delay
    movb  $0x20, %al                                /* ����Ӳ���жϿ�ʼ�� (0x20) */
    out   %al, $0x21
    call  _delay
    movb  $0x28, %al                                /* ����Ӳ���жϿ�ʼ�� (0x28) */
    out   %al, $0xA1
    call  _delay
    movb  $0x04, %al                                /* ������Ƭ */
    out   %al, $0x21
    call  _delay
    movb  $0x02, %al                                /* ���ô�Ƭ */
    out   %al, $0xA1
    call  _delay
    movb  $0x01, %al                                /* 8086 mode */
    out   %al, $0x21
    call  _delay
    out   %al, $0xA1
    call  _delay                                    /* �������� */
    movb  $0xfb, %al
    out   %al, $0x21
    call  _delay
    movb  $0xff, %al
    out   %al, $0xA1
    ret
_delay:                                             /* �ӳ� */
    ret

/*****************************************************************/
/*                                                               */
/*                 ��ʼ��������IDT                               */
/*                                                               */
/*****************************************************************/
init_idt:
    movl    $ignore_int, %edx
    movl    $0x00100000, %eax
    movw    %dx, %ax
    movw    $0x8e00, %dx
    movl    $_idt, %edi
    movl    $256, %ecx
rp_sidt:
    movl    %eax, (%edi)
    movl    %edx, 4(%edi)
    addl    $8, %edi
    decl    %ecx
    jne     rp_sidt
    lidtl   (_idt_pdesc)
    ret
ignore_int:                                         /* Ĭ���жϴ�������ʲôҲ���� */
    iret
    
/*****************************************************************/
/*                                                               */
/*                 idt gdt idt������ gdt������                   */
/*                                                               */
/*****************************************************************/

.data
    .align  2
_idt_pdesc:                                         /* idtα������ */
    .short  256*8-1                                 /* idt contains 256 entries */    
    .long   _idt

    .align  2
_gdt_pdesc:                                         /* gdtα������ */
    .short  256*8-1                                 /* But I think we must large it.    */
    .long   _gdt                                    /* Or only use one ldt and tss      */
                                                    /* in our system.                   */
    .align  8
_idt:
    .fill   256,8,0                                 /* �ж�����ʱΪ�� */
    
    .align  2 
_gdt:                                               /* �ĸ��� ���Ĵ���� �������ݶ� �û������ �û����ݶ� */

    .short  0                                       /* ��ʹ�� */
    .short  0
    .short  0
    .short  0
    
    .short  0xFFFF                                  /* kernel cs 0x08 (1) */
    .short  0x0000                                  /* base: 0, limit: 4G */
    .short  0x9A00                                  /* Type: present,ring0,data/stack,read/write (10010010) */
    .short  0x00CF                                  /* Limit(1):0xF | Flags:4Kb inc,32bit (11001111)    F --->���޸�4λ */

    .short  0xFFFF                                  /* kernel ds 0x10 (2) */
    .short  0x0000                                  /* base: 0, limit: 4G */
    .short  0x9200
    .short  0x00CF

    .short  0xFFFF                                  /* user  cs 0x1B  (3)   11    0-��GDT�� 11 ��Ȩ��Ϊ 3 */
    .short  0x0000                                  /* base: 0, limit: 4G */
    .short  0xFA00     
    .short  0x00CF

    .short  0xFFFF                                  /* user ds 0x23   (4)    100  0-��GDT�� 11 ��Ȩ��Ϊ 3 */
    .short  0x0000                                  /* base: 0, limit: 4G */
    .short  0xF200
    .short  0x00CF

    .fill   251,8,0