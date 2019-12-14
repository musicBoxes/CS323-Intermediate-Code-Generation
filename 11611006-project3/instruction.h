#ifndef SPL_INSTRUCTION
#define SPL_INSTRUCTION

typedef struct TAC{
	char seg[6][12]; // "FUNCTION" is 8 bytes... 
} TAC;

void printTAC(TAC *tac){
	int idx = 0;
	printf("%s", tac->seg[idx++]);
	while (tac->seg[idx][0] != 0) {
		printf(" %s", tac->seg[idx++]);
	}
	printf("\n");
}

// LABEL x : | define a label x
void TAC_Label(TAC *tac, char *x){
	strcpy(tac->seg[0], "LABEL");
	strcpy(tac->seg[1], x);
	strcpy(tac->seg[2], ":");
}
// FUNCTION f : | define a function f
void TAC_Function(TAC *tac, char *f){
	strcpy(tac->seg[0], "FUNCTION");
	strcpy(tac->seg[1], f);
	strcpy(tac->seg[2], ":");
}
// x := y | assign value of y to x
void TAC_Assign(TAC *tac, char *x, char *y){
	strcpy(tac->seg[0], x);
	strcpy(tac->seg[1], ":=");
	strcpy(tac->seg[2], y);
}
// x := y + z | arithmetic addition
void TAC_Add(TAC *tac, char *x, char *y, char *z){
	strcpy(tac->seg[0], x);
	strcpy(tac->seg[1], ":=");
	strcpy(tac->seg[2], y);
	strcpy(tac->seg[3], "+");
	strcpy(tac->seg[4], z);
}
// x := y - z | arithmetic subtraction
void TAC_Sub(TAC *tac, char *x, char *y, char *z){
	strcpy(tac->seg[0], x);
	strcpy(tac->seg[1], ":=");
	strcpy(tac->seg[2], y);
	strcpy(tac->seg[3], "-");
	strcpy(tac->seg[4], z);
}
// x := y * z | arithmetic multiplication
void TAC_Mul(TAC *tac, char *x, char *y, char *z){
	strcpy(tac->seg[0], x);
	strcpy(tac->seg[1], ":=");
	strcpy(tac->seg[2], y);
	strcpy(tac->seg[3], "*");
	strcpy(tac->seg[4], z);
}
// x := y / z | arithmetic division
void TAC_Div(TAC *tac, char *x, char *y, char *z){
	strcpy(tac->seg[0], x);
	strcpy(tac->seg[1], ":=");
	strcpy(tac->seg[2], y);
	strcpy(tac->seg[3], "/");
	strcpy(tac->seg[4], z);
}
// x := &y | assign address of y to x
void TAC_AssignAddr(TAC *tac, char *x, char *y){
	strcpy(tac->seg[0], x);
	strcpy(tac->seg[1], ":=");
	tac->seg[2][0] = '&';
	strcpy(tac->seg[2]+1, y);
}
// x := *y | assign value stored in address y to x
void TAC_AssignValInAddr(TAC *tac, char *x, char *y){
	strcpy(tac->seg[0], x);
	strcpy(tac->seg[1], ":=");
	tac->seg[2][0] = '*';
	strcpy(tac->seg[2]+1, y);
}
// *x := y | copy value y to address x
void TAC_AssignToAddr(TAC *tac, char *x, char *y){
	tac->seg[0][0] = '*';
	strcpy(tac->seg[0]+1, x);
	strcpy(tac->seg[1], ":=");
	strcpy(tac->seg[2], y);
}
// GOTO x | unconditional jump to label x
void TAC_Goto(TAC *tac, char *x){
	strcpy(tac->seg[0], "GOTO");
	strcpy(tac->seg[1], x);
}
// IF x [relop] y GOTO z | if the condition (binary boolean) is true, jump to label z
void TAC_If(TAC *tac, char *x, char *relop, char *y, char *z){
	strcpy(tac->seg[0], "IF");
	strcpy(tac->seg[1], x);
	strcpy(tac->seg[2], relop);
	strcpy(tac->seg[3], y);
	strcpy(tac->seg[4], "GOTO");
	strcpy(tac->seg[5], z);
}
// RETURN x | exit the current function and return value x
void TAC_Return(TAC *tac, char *x){
	strcpy(tac->seg[0], "RETURN");
	strcpy(tac->seg[1], x);
}
// DEC x [size] | allocate space pointed by x, size must be a multiple of 4
void TAC_Dec(TAC *tac, char *x, int bytes){
	strcpy(tac->seg[0], "DEC");
	strcpy(tac->seg[1], x);
	sprintf(tac->seg[2], "%d", bytes);
}
// PARAM x | declare a function parameter
void TAC_Param(TAC *tac, char *x){
	strcpy(tac->seg[0], "PARAM");
	strcpy(tac->seg[1], x);
}
// ARG x | pass argument x
void TAC_Arg(TAC *tac, char *x){
	strcpy(tac->seg[0], "ARG");
	strcpy(tac->seg[1], x);
}
// x := CALL f | call a function, assign the return value to x
void TAC_Call(TAC *tac, char *x, char *f){
	strcpy(tac->seg[0], x);
	strcpy(tac->seg[1], ":=");
	strcpy(tac->seg[2], "CALL");
	strcpy(tac->seg[3], f);
}
// READ x | read x from console
void TAC_Read(TAC *tac, char *x){
	strcpy(tac->seg[0], "READ");
	strcpy(tac->seg[1], x);
}
// WRITE x print the value of x to console
void TAC_Write(TAC *tac, char *x){
	strcpy(tac->seg[0], "WRITE");
	strcpy(tac->seg[1], x);
}
#endif