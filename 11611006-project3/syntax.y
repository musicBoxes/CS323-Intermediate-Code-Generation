%{
	#include "tree.h"
	#define YYSTYPE struct treeNode*
	#include "list.h"
	
    #ifndef LEX
	#define LEX
	#include "lex.yy.c"
	#endif
	
	#include "instruction.h"
	
	int childNum;
	int error_flag = 0;
	char errmsg[100];
	
	int loop_flag = 0;
	
	// used in IR
	int inter_idx = 0;
	int label_idx = 0;
	TAC spl_instruction[1024];
	int whileStart[1024];
	int instruction_cnt = 0;
	const char *interVar = "dyj";
	
	// temporary store child node
	struct treeNode* childNodeList[10];
	
	// temporarily store a list of variable
	struct FieldList* tmpList;
	
	// global
	struct FieldList* globalVariableList;
	struct FieldList* globalStructList;
	
	// funcList is already global
	struct FieldList* funcList;
	
	// store all variable in {  }
	// each member is a List 
	// use '->vars' to get all variables
	struct FieldList* allTmpVarList;
	struct FieldList* structList;
	
	struct FieldList* retList;
	struct FieldList* funcArgs;
	
	struct FieldList* curFunc;
	
	// array 
	char *varName; // record variable name when it is defined
	int varCnt = 1; // record variable name when it is defined
	
	Type *baseType;
	Type *arrayType; 
	Type *funcRetType;
	
	void yyerror(char*);
	
	FieldList* validDecDefVar(char *name);
	FieldList* validUseVar(char *name);
	
	// return 0 if variable add successfully
	// return 1 means error
	int addVar(FieldList*, struct treeNode*, int);
	int addFuncStruct(FieldList* head, char* funcName, Type *type, int lineno);
	
	Type* isValidAssign(struct treeNode *a, struct treeNode *b, int lineno);
	Type* isValidOperation(struct treeNode *a, struct treeNode *b, char *operation, int lineno);
	Type* getExpTypePtr(struct treeNode* node, int lineno);
	Type* parseSpecifier(struct treeNode* node);
	
	void backPatch(int patchIdx, int inst);
	void backPatchList(int *list, int inst);
%}
%token TYPE ID CHAR FLOAT INT VOID
%token STRUCT IF ELSE WHILE FOR RETURN BREAK
%token DOT SEMI COMMA ASSIGN LT LE GT GE NE EQ 
%token PLUS MINUS MUL DIV AND OR NOT LP RP LB RB LC RC 
%token CS CE
%token UMINUS
%right ASSIGN
%left OR 
%left AND 
%left LT LE GT GE EQ NE 
%left PLUS MINUS 
%left UMINUS
%left MUL DIV
%right NOT
%left DOT LB RB LP RP
%%
Program: ExtDefList { 
		childNum = 1; childNodeList[0]=$1; $$=createNode(childNum, childNodeList, "Program", @$.first_line); 
		//if (!error_flag) 
		//	treePrint($$); 
	}
    ;
ExtDefList: ExtDef ExtDefList { childNum = 2; childNodeList[0]=$1; childNodeList[1]=$2; $$=createNode(childNum, childNodeList, "ExtDefList", @$.first_line); }
    | %empty { $$=createEmpty(); }
    ;
ExtDef: Specifier ExtDecList SEMI { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "ExtDef", @$.first_line); 
		list_link(globalVariableList, tmpList);
		//list_link(globalStructList, structList);
	}
    | Specifier SEMI { childNum = 2; childNodeList[0]=$1; childNodeList[1]=$2; $$=createNode(childNum, childNodeList, "ExtDef", @$.first_line); }
    | Specifier FunDec CompSt { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "ExtDef", @$.first_line); 
		funcRetType = parseSpecifier($1);
		list_getLast(funcList)->type = funcRetType;
		FieldList* ret = retList->next;
		// delete member after checking
		while (ret != NULL){
			if (!isSameType(ret->type, funcRetType)){
				printf("Error type 8 at Line %d: Function’s return value type mismatches the declared type\n", ret->lineno);
			}
			ret = ret->next;
		}
		list_clear(retList);
	}
    | Specifier ExtDecList error { printf("Error type B at Line %d: Missing ';'\n", @$.first_line); error_flag = 1; }
	;
ExtDecList: VarDec { 
		childNum = 1; childNodeList[0]=$1; $$=createNode(childNum, childNodeList, "ExtDecList", @$.first_line);
		addVar(tmpList, $1, @$.first_line);
	}
    | VarDec COMMA ExtDecList { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "ExtDecList", @$.first_line); 
		addVar(tmpList, $1, @$.first_line);
	}
    ;
Specifier: TYPE { 
		childNum = 1; childNodeList[0]=$1; $$=createNode(childNum, childNodeList, "Specifier", @$.first_line); 
		// "TYPE :"
		switch (*($1->value+6)){
			case 'i':
				baseType = &INT_TYPE;
				break;
			case 'f':
				baseType = &FLOAT_TYPE;
				break;
			case 'c':
				baseType = &CHAR_TYPE;
				break;
		}
		//printf("INT %d FLOAT %d CHAR %d: %d %s\n", INT, FLOAT, CHAR, baseType.primitive, baseType.name);
	}
    | StructSpecifier { 
		childNum = 1; childNodeList[0]=$1; $$=createNode(childNum, childNodeList, "Specifier", @$.first_line); 
	}
    ;
StructSpecifier: STRUCT ID LC DefList RC { 
		childNum = 5; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; childNodeList[3]=$4; childNodeList[4]=$5; $$=createNode(childNum, childNodeList, "StructSpecifier", @$.first_line); 
		baseType = (Type*)malloc(sizeof(Type)); memset(baseType, 0, sizeof(Type));
		baseType->category = STRUCTURE;
		baseType->structure = (FieldList*)malloc(sizeof(FieldList)); memset(baseType->structure, 0, sizeof(FieldList));
		list_link(baseType->structure, list_getLast(allTmpVarList)->vars);
		list_deleteLast(allTmpVarList);
		addFuncStruct(structList, $2->value+4, baseType, @2.first_line); //"ID: "
	}
    | STRUCT ID { 
		childNum = 2; childNodeList[0]=$1; childNodeList[1]=$2; $$=createNode(childNum, childNodeList, "StructSpecifier", @$.first_line); 
		FieldList *structType;
		//"ID: "
		if ((structType = list_findByName(structList, $2->value+4)) != NULL){
			baseType = structType->type;
		}
		else{
			error_flag = 1;
			printf("Semantic Error at line %d: Struct '%s' is used without definition.\n", @2.first_line, $2->value+4);
		}
	}
    ;
VarDec: ID { 
		childNum = 1; childNodeList[0]=$1; $$=createNode(childNum, childNodeList, "VarDec", @$.first_line); 
		varName = $1->value+4; //"ID: ";
		//printf(varName);
	}
    | VarDec LB INT RB { 
		childNum = 4; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; childNodeList[3]=$4; $$=createNode(childNum, childNodeList, "VarDec", @$.first_line); 
		Type *lastArrayType = arrayType;
		arrayType = (Type*)malloc(sizeof(Type)); memset(arrayType, 0, sizeof(Type));
		Array *array = (Array*)malloc(sizeof(Array)); memset(array, 0, sizeof(Array));
		if (lastArrayType == NULL){ // first dimension
			array->base = baseType;
		}
		else{
			array->base = lastArrayType;
		}
		array->size = strToInt($3->value+5); // "INT: "
		varCnt *= array->size;
		arrayType->category = ARRAY;
		arrayType->array = array;
	}
    ;
FunDec: ID LP VarList RP { 
		childNum = 4; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; childNodeList[3]=$4; $$=createNode(childNum, childNodeList, "FunDec", @$.first_line); 
		// we do not need to know function return type in here
		// return type check will be done after FunDec be recognized
		addFuncStruct(funcList, $1->value+4, NULL, @1.first_line); // "ID: "
		curFunc = list_getLast(funcList);
		curFunc->args = (FieldList*)malloc(sizeof(FieldList)); memset(curFunc->args, 0, sizeof(FieldList));
		list_link(curFunc->args, tmpList);
		TAC_Function(spl_instruction+instruction_cnt, $1->value+4); instruction_cnt ++; // "ID: "
		FieldList* curVar = curFunc->args->next;
		while (curVar != NULL){
			if (curVar->type->category == PRIMITIVE){
				TAC_Param(spl_instruction+instruction_cnt, curVar->name); instruction_cnt ++;
			}
			else{
				
			}
			curVar = curVar->next;
		}
	}
    | ID LP RP { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "FunDec", @$.first_line); 
		addFuncStruct(funcList, $1->value+4, NULL, @1.first_line); // "ID: "
		//printf("FunDec -> ID LP RP\n");
		curFunc = list_getLast(funcList);
		curFunc->args = NULL;
		TAC_Function(spl_instruction+instruction_cnt, $1->value+4); instruction_cnt ++; //"ID: "
	}
    | ID LP error { printf("Error type B at Line %d: Missing \")\"\n", @$.first_line); error_flag = 1; }
	;
VarList: ParamDec COMMA VarList { childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "VarList", @$.first_line); }
    | ParamDec { childNum = 1; childNodeList[0]=$1; $$=createNode(childNum, childNodeList, "VarList", @$.first_line); }
    ;
ParamDec: Specifier VarDec { 
		childNum = 2; childNodeList[0]=$1; childNodeList[1]=$2; $$=createNode(childNum, childNodeList, "ParamDec", @$.first_line); 
		addVar(tmpList, $2, @$.first_line);
	}
    ;
CompSt: LC DefList StmtList RC { 
		childNum = 4; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; childNodeList[3]=$4; $$=createNode(childNum, childNodeList, "CompSt", @$.first_line); 
		list_deleteLast(allTmpVarList);
	}
	| LC DefList StmtList error { printf("Error type B at Line %d: Missing \"}\"\n", @$.first_line); error_flag = 1; }
//	| LC DefList StmtList Def StmtList DefStmtList RC { printf("Error type B at Line %d: Definition must at head.\n", @4.first_line); error_flag = 1; }
	;
DefStmtList: Def StmtList
	| %empty
	;
StmtList: Stmt StmtList { childNum = 2; childNodeList[0]=$1; childNodeList[1]=$2; $$=createNode(childNum, childNodeList, "StmtList", @$.first_line); }
    | %empty { $$=createEmpty(); }
//	| Def DefList { printf("Error type B at Line %d: Definition must at head.\n", @$.first_line); error_flag = 1; }
    ;
Stmt: Exp SEMI { 
		childNum = 2; childNodeList[0]=$1; childNodeList[1]=$2; $$=createNode(childNum, childNodeList, "Stmt", @$.first_line); 
		//printf("Stmt -> Exp SEMI\n");
	}
    | CompSt { 
		//printf("Stmt -> CompSt\n");
		childNum = 1; childNodeList[0]=$1; $$=createNode(childNum, childNodeList, "Stmt", @$.first_line); 
	}
    | RETURN Exp SEMI { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Stmt", @$.first_line); 
		FieldList *ret = (FieldList*)malloc(sizeof(FieldList)); memset(ret, 0, sizeof(FieldList));
		ret->lineno = @2.first_line;
		ret->type = getExpTypePtr($2, @2.first_line);
		list_pushBack(retList, ret);
		TAC_Return(spl_instruction+instruction_cnt, $2->expVal); instruction_cnt ++;
	}
    | IF LP Exp RP L Stmt L { 
		childNum = 5; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; childNodeList[3]=$4; childNodeList[4]=$6; $$=createNode(childNum, childNodeList, "Stmt", @$.first_line); 
		//printf("IF LP Exp RP L Stmt L\n");
		Type *typePtr = getExpTypePtr($3, @3.first_line);
		if (!(typePtr->category == PRIMITIVE && typePtr->primitive == INT)){
			error_flag = 1;
			printf("Semantic Error at line %d: Use non-int type variable as condition.\n", @3.first_line);
		}
		else{
			//printf("IF LP Exp RP L Stmt L\n");
			backPatchList($3->trueList, $5->inst);
			backPatchList($3->falseList, $7->inst);
		}
	}
    | IF LP Exp RP L Stmt G ELSE L Stmt L { 
		childNum = 7; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; childNodeList[3]=$4; childNodeList[4]=$5; childNodeList[5]=$6; childNodeList[6]=$7; $$=createNode(childNum, childNodeList, "Stmt", @$.first_line); 
		Type *typePtr = getExpTypePtr($3, @3.first_line);
		if (!(typePtr->category == PRIMITIVE && typePtr->primitive == INT)){
			error_flag = 1;
			printf("Semantic Error at line %d: Use non-int type variable as condition.\n", @3.first_line);
		}
		else{
			//printf("IF LP Exp RP L Stmt L\n");
			backPatchList($3->trueList, $5->inst);
			backPatchList($3->falseList, $9->inst);
			backPatch($7->inst, $11->inst);
		}
	}
    | WHILE LP Exp RP L Stmt G L { 
		childNum = 5; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; childNodeList[3]=$4; childNodeList[4]=$5; $$=createNode(childNum, childNodeList, "Stmt", @$.first_line); 
		Type *typePtr = getExpTypePtr($3, @3.first_line);
		if (!(typePtr->category == PRIMITIVE && typePtr->primitive == INT)){
			error_flag = 1;
			printf("Semantic Error at line %d: Use non-int type variable as condition.\n", @3.first_line);
		}
		else{
			/*
			backPatchList($4->trueList, $6->inst);
			backPatchList($4->falseList, $9->inst);
			backPatch($8->inst, $2->inst);
			*/
			
			backPatchList($3->trueList, $5->inst);
			backPatchList($3->falseList, $8->inst);
			backPatch($7->inst, whileStart[--loop_flag]);
		}
	}
//	| Exp error { printf("Error type B at Line %d: Exp error\n", @$.first_line); error_flag = 1; }
	| RETURN Exp error { printf("Error type B at Line %d: Missing \";\"\n", @$.first_line); error_flag = 1; } 
//	| RETURN error SEMI { printf("Error type B at Line %d: RETURN error SEMI\n", @$.first_line); error_flag = 1; } 
	| FOR LP Def ExpListEx SEMI ExpListEx RP Stmt { 
		childNum = 8; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; childNodeList[3]=$4; childNodeList[4]=$5; childNodeList[5]=$6; childNodeList[6]=$7; childNodeList[7]=$8; $$=createNode(childNum, childNodeList, "Stmt", @$.first_line); 
		loop_flag--;
	}
	| FOR LP ExpListEx SEMI ExpListEx SEMI ExpListEx RP Stmt { 
		childNum = 9; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; childNodeList[3]=$4; childNodeList[4]=$5; childNodeList[5]=$6; childNodeList[6]=$7; childNodeList[7]=$8; childNodeList[8]=$9; $$=createNode(childNum, childNodeList, "Stmt", @$.first_line); 
		loop_flag--;
	}
	| BREAK SEMI { 
		childNum = 2; childNodeList[0]=$1; childNodeList[1]=$2; $$=createNode(childNum, childNodeList, "Stmt", @$.first_line); 
		//printf("loop flag = %d\n", loop_flag);
		if (!loop_flag) {
			error_flag = 1;
			printf("Semantic Error at line %d: 'break' should be used in loop.\n", @1.first_line);
		}
	}
	;
DefList: Def DefList { 
		childNum = 2; childNodeList[0]=$1; childNodeList[1]=$2; $$=createNode(childNum, childNodeList, "DefList", @$.first_line); 
	}
    | %empty { 
		$$=createEmpty(); 
		FieldList* varDefList = (FieldList*)malloc(sizeof(FieldList)); memset(varDefList, 0, sizeof(FieldList));
		varDefList->vars = (FieldList*)malloc(sizeof(FieldList)); memset(varDefList->vars, 0, sizeof(FieldList));
		list_link(varDefList->vars, tmpList);
		list_pushBack(allTmpVarList, varDefList);
	}
    ;
Def: Specifier DecList SEMI { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Def", @$.first_line); 
		if (strcmp($1->child[0]->value, "TYPE")) {// int float char
			
		}
		else{
			
		}
	}
    | Specifier DecList error { printf("Error type B at Line %d: Missing \";\"\n", @$.first_line); error_flag = 1; }
	;
DecList: Dec { childNum = 1; childNodeList[0]=$1; $$=createNode(childNum, childNodeList, "DecList", @$.first_line); }
    | Dec COMMA DecList { childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "DecList", @$.first_line); }
    ;
Dec: VarDec { 
		childNum = 1; childNodeList[0]=$1; $$=createNode(childNum, childNodeList, "Dec", @$.first_line); 
		if (addVar(tmpList, $1, @$.first_line) == 0){
			if (baseType->category != PRIMITIVE){
				TAC_Dec(spl_instruction+instruction_cnt, $1->child[0]->value+4, getTypeSize(baseType)); instruction_cnt ++; // "ID: "
			}
		}
	}
    | VarDec ASSIGN Exp { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Dec", @$.first_line); 
		if (addVar(tmpList, $1, @$.first_line) == 0){
			Type *typePtr = getExpTypePtr($3, @2.first_line);
			//printf("%s Exp category = %d\n", $1->child[0]->value, typePtr->category);
			if (!isSameType(typePtr, list_getLast(tmpList)->type)){
				error_flag = 1;
				printf("Error type 5 at Line %d: unmatching type on both sides of assignment\n", @2.first_line);
			}
			else{
				if (baseType->category != PRIMITIVE){
					//TAC_Dec(spl_instruction+instruction_cnt, $1->value+4, getTypeSize(baseType)); instruction_cnt ++; // "ID: "
				}
				TAC_Assign(spl_instruction+instruction_cnt, varName, $3->expVal); instruction_cnt ++;
			}
		}
	}
//	| VarDec ASSIGN error { printf("Error type B at Line %d: VarDec ASSIGN error\n", @$.first_line); error_flag = 1; }
	;
Exp: Exp ASSIGN Exp { 
		//printf("Exp -> Exp ASSIGN Exp\n");
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		Type *typePtr = isValidAssign($1, $3, @2.first_line);
		if (typePtr->category == DIFFERENT) {
			error_flag = 1;
			printf("Error type 5 at Line %d: unmatching type on both sides of assignment\n", @2.first_line);
		}
		if ($1->childNum == 1) {
			char str[5]; memset(str, 0, sizeof(str));
			memcpy(str, $1->child[0]->value, sizeof(char)*4);
			if (!strcmp(str, "INT:") || !strcmp(str, "CHAR") || !strcmp(str, "FLOA")){
				error_flag = 1;
				printf("Error type 6 at Line %d: rvalue on the left side of assignment operator\n", @1.first_line);
			}
		}
		if ($1->isAddr){
			char expVal[16]; memset(expVal, 0, sizeof(expVal));
			expVal[0] = '*'; strcpy(expVal+1, $1->expVal);
			TAC_Assign(spl_instruction+instruction_cnt, expVal, $3->expVal); instruction_cnt ++;
		}
		else{
			TAC_Assign(spl_instruction+instruction_cnt, $1->expVal, $3->expVal); instruction_cnt ++;
		}
	}
    | Exp AND L Exp { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$4; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		backPatchList($1->trueList, $3->inst);
		memcpy($$->trueList, $4->trueList, sizeof($$->trueList));
		mergeList($$->falseList, $1->falseList, $4->falseList);
		//int *ptr = $$->falseList; while (*ptr != 0) printf("%d\n", *ptr), ptr ++;
	}
    | Exp OR L Exp { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$4; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		backPatchList($1->falseList, $3->inst);
		memcpy($$->falseList, $4->falseList, sizeof($$->falseList));
		mergeList($$->trueList, $1->trueList, $4->trueList);
	}
    | Exp LT Exp { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		$$->trueList[0] = instruction_cnt;
		$$->falseList[0] = instruction_cnt+1;
		TAC_If(spl_instruction+instruction_cnt, $1->expVal, "<", $3->expVal, ""); instruction_cnt ++;// "" need to be backpatch
		TAC_Goto(spl_instruction+instruction_cnt, ""); instruction_cnt ++;
	}
    | Exp LE Exp { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		$$->trueList[0] = instruction_cnt;
		$$->falseList[0] = instruction_cnt+1;
		TAC_If(spl_instruction+instruction_cnt, $1->expVal, "<=", $3->expVal, ""); instruction_cnt ++;// "" need to be backpatch
		TAC_Goto(spl_instruction+instruction_cnt, ""); instruction_cnt ++;
	}
    | Exp GT Exp { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		$$->trueList[0] = instruction_cnt;
		$$->falseList[0] = instruction_cnt+1;
		TAC_If(spl_instruction+instruction_cnt, $1->expVal, ">", $3->expVal, ""); instruction_cnt ++;// "" need to be backpatch
		TAC_Goto(spl_instruction+instruction_cnt, ""); instruction_cnt ++;
	}
    | Exp GE Exp { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		$$->trueList[0] = instruction_cnt;
		$$->falseList[0] = instruction_cnt+1;
		TAC_If(spl_instruction+instruction_cnt, $1->expVal, ">=", $3->expVal, ""); instruction_cnt ++;// "" need to be backpatch
		TAC_Goto(spl_instruction+instruction_cnt, ""); instruction_cnt ++;
	}
    | Exp NE Exp { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		$$->trueList[0] = instruction_cnt;
		$$->falseList[0] = instruction_cnt+1;
		TAC_If(spl_instruction+instruction_cnt, $1->expVal, "!=", $3->expVal, ""); instruction_cnt ++;// "" need to be backpatch
		TAC_Goto(spl_instruction+instruction_cnt, ""); instruction_cnt ++;
	}
    | Exp EQ Exp { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Exp", @$.first_line);
		$$->trueList[0] = instruction_cnt;
		$$->falseList[0] = instruction_cnt+1;
		TAC_If(spl_instruction+instruction_cnt, $1->expVal, "==", $3->expVal, ""); instruction_cnt ++;// "" need to be backpatch
		TAC_Goto(spl_instruction+instruction_cnt, ""); instruction_cnt ++;		
	}
    | Exp PLUS Exp { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		char tmpVar[8]; sprintf(tmpVar, "%s%d", interVar, inter_idx++);
		char tmp[16]; 
		memset(tmp, 0, sizeof(tmp));
		if ($1->isAddr){
			tmp[0] = '*';
			strcpy(tmp+1, $1->expVal);
			strcpy($1->expVal, tmp);
		}
		if ($3->isAddr){
			tmp[0] = '*';
			strcpy(tmp+1, $3->expVal);
			strcpy($3->expVal, tmp);
		}
		TAC_Add(spl_instruction+instruction_cnt, tmpVar, $1->expVal, $3->expVal); instruction_cnt ++;
		strcpy($$->expVal, tmpVar);
	}
    | Exp MINUS Exp { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		char tmpVar[8]; sprintf(tmpVar, "%s%d", interVar, inter_idx++);
		TAC_Sub(spl_instruction+instruction_cnt, tmpVar, $1->expVal, $3->expVal); instruction_cnt ++;
		strcpy($$->expVal, tmpVar);
	}
    | Exp MUL Exp { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		char tmpVar[8]; sprintf(tmpVar, "%s%d", interVar, inter_idx++);
		TAC_Mul(spl_instruction+instruction_cnt, tmpVar, $1->expVal, $3->expVal); instruction_cnt ++;
		strcpy($$->expVal, tmpVar);
	}
    | Exp DIV Exp {
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		char tmpVar[8]; sprintf(tmpVar, "%s%d", interVar, inter_idx++);
		TAC_Div(spl_instruction+instruction_cnt, tmpVar, $1->expVal, $3->expVal); instruction_cnt ++;
		strcpy($$->expVal, tmpVar);
	}
    | LP Exp RP { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		strcpy($$->expVal, $2->expVal);
	}
    | MINUS Exp %prec UMINUS{ 
		childNum = 2; childNodeList[0]=$1; childNodeList[1]=$2; $$=createNode(childNum, childNodeList, "Exp", @$.first_line);
		//printf("%s\n", $2->expVal);
		if ($2->expVal[0] == '#'){ // constant number
			$$->expVal[0] = '#';
			if ($2->expVal[1] == '-'){ // negative number
				strcpy($$->expVal+1, $2->expVal+2);
				//printf("negative constant number\n");
			}
			else{
				$$->expVal[1] = '-';
				strcpy($$->expVal+2, $2->expVal+1);
				//printf("positive constant number %c %s %s\n", $$->expVal[1], $2->expVal+1, $$->expVal);
			}
		}
		else{ // variable
			if ($2->expVal[0] == '-'){ // negative
				strcpy($$->expVal, $2->expVal+1);
				//printf("negative\n");
			}
			else{
				$$->expVal[0] = '-';
				strcpy($$->expVal+1, $2->expVal);
				//printf("positive\n");
			}
		}
	}
    | NOT Exp { childNum = 2; childNodeList[0]=$1; childNodeList[1]=$2; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); }
    | ID LP Args RP { 
		childNum = 4; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; childNodeList[3]=$4; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		//printf("Size = %d %s\n", list_size(funcList), $1->value+4);
		FieldList* func;
		if ((func = list_findByName(funcList, $1->value+4)) == NULL) { // "ID: "
			error_flag = 1;
			if (validUseVar($1->value+4)){
				printf("Error type 11 at Line %d: Applying function invocation operator '()' on non-function names '%s'\n", @1.first_line, $1->value+4);
			}
			else{
				printf("Error type 2 at Line %d: Function '%s' is invoked without definition\n", @1.first_line, $1->value+4);
			}
			goto clearArg;
		}
		//printf("%d\n", func->args);
		if (func->args == NULL){
			error_flag = 1;
			printf("Error type 9 at Line %d: Function’s arguments mismatch the declared parameters\n", @3.first_line);
			goto clearArg;
		}
		FieldList *cur1 = func->args->next;
		FieldList *cur2 = funcArgs->next;
		int ok = 1;
		//FieldList *p1 = cur1, *p2 = cur2;
		//int cnt1 = 0, cnt2 = 0;
		//while (p1 != NULL) cnt1 ++, p1 = p1->next;
		//while (p2 != NULL) cnt2 ++, p2 = p2->next;
		//printf("len1 = %d len2 = %d\n", cnt1, cnt2);
		//printf("Size %d %d\n", list_size(func->args), list_size(funcArgs));
		while (cur1 != NULL && cur2 != NULL){
			if (!isSameType(cur1->type, cur2->type)){
				ok = 0;
				break;
			}
			cur1 = cur1->next;
			cur2 = cur2->next;
		}
		if (!ok || (cur1 == NULL && cur2 != NULL) || (cur1 != NULL && cur2 == NULL)){
			printf("Error type 9 at Line %d: Function’s arguments mismatch the declared parameters\n", @3.first_line);
			goto clearArg;
		}
		//printf("%s\n", func->name);
		if (!strcmp(func->name, "write")) { // just one arg
			TAC_Write(spl_instruction+instruction_cnt, funcArgs->next->name); instruction_cnt ++;
			goto clearArg;
		}
		else{
			FieldList* curVar = funcArgs->next;
			while (curVar != NULL){
				TAC_Arg(spl_instruction+instruction_cnt, curVar->name); instruction_cnt ++;
				curVar = curVar->next;
			}
			TAC_Call(spl_instruction+instruction_cnt, interVar, func->name); instruction_cnt ++;
			strcpy($$->expVal, interVar);
		}
		clearArg:
		list_clear(funcArgs);
	}
    | ID LP RP { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		FieldList* curFunc;
		if ((curFunc = list_findByName(funcList, $1->value+4)) == NULL) { // "ID: "
			error_flag = 1;
			if (validUseVar($1->value+4)){
				printf("Error type 11 at Line %d: Applying function invocation operator '()' on non-function names '%s'\n", @1.first_line, $1->value+4);
			}
			else{
				printf("Error type 2 at Line %d: Function '%s' is invoked without definition\n", @1.first_line, $1->value+4);
			}
		}
		else{
			if (!strcmp($1->value+4, "read")){ // "ID: " read()
				TAC_Read(spl_instruction+instruction_cnt, interVar); instruction_cnt++;
				strcpy($$->expVal, interVar);
			}
			else{ // other function
				if (curFunc->args != NULL){
					printf("Error type 9 at Line %d: Function’s arguments mismatch the declared parameters\n", @1.first_line);
				}
				else{
					TAC_Call(spl_instruction+instruction_cnt, interVar, $1->value+4); instruction_cnt++; // "ID: "
				}
			}
		}
	}
    | Exp LB Exp RB { childNum = 4; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; childNodeList[3]=$4; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); }
    | Exp DOT ID { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		// return pointer
		Type* typePtr = getExpTypePtr($1, @1.first_line);
		if (typePtr->category == STRUCTURE){
			FieldList* structField = typePtr->structure->next;
			FieldList* stack[16]; int size = 0;
			while (structField != NULL){
				stack[size ++] = structField;
				structField = structField->next;
			}
			int offset = 0;
			for (int i = size-1 ; i >= 0 && !strcmp(stack[i]->name, $3->value+4) ; i --){
				offset += getTypeSize(stack[i]->type);
			}
			char tmpVar[16]; memset(tmpVar, 0, sizeof(tmpVar));
			sprintf(tmpVar, "%s%d", interVar, inter_idx++);
			char constNum[16]; memset(constNum, 0, sizeof(constNum));
			sprintf(constNum, "#%d", offset);
			TAC_Add(spl_instruction+instruction_cnt, tmpVar, $1->expVal, constNum); instruction_cnt ++;
			strcpy($$->expVal, tmpVar);
			$$->isAddr = 1;
		}
	}
    | ID { 
		childNum = 1; childNodeList[0]=$1; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		FieldList* curVar;
		if ((curVar = validUseVar($1->value+4)) == NULL) { //"ID: "
			error_flag = 1;
			printf("Error type 1 at Line %d: Variable '%s' is not defined\n", @$.first_line, $1->value+4);
		}
		else{
			if (curVar->type->category == PRIMITIVE){ // for primitive type, just return itself
				strcpy($$->expVal, $1->value+4);
			}
			else { // for other type, return its pointer
				//$$->expVal[0] = '&'; strcpy($$->expVal+1, $1->value+4);
				strcpy($$->expVal, $1->value+4); $$->isAddr = 1;
			}
		}
	}
    | INT { 
		childNum = 1; childNodeList[0]=$1; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); 
		sprintf($$->expVal, "#%s", $1->value+5); // "INT: "
	}
    | FLOAT { childNum = 1; childNodeList[0]=$1; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); }
    | CHAR { childNum = 1; childNodeList[0]=$1; $$=createNode(childNum, childNodeList, "Exp", @$.first_line); }
    | ID LP Args error { printf("Error type B at Line %d: Missing \")\"\n", @$.first_line); error_flag = 1; }
//	| Exp ASSIGN error { printf("Error type B at Line %d: Exp ASSIGN error\n", @$.first_line); error_flag = 1; } // 20 reduce/reduce conflicts
	| error { /*printf("error\n"); yyerrok;*/ error_flag = 1; }
	;
ExpList: Exp { childNum = 1; childNodeList[0]=$1; $$=createNode(childNum, childNodeList, "ExpList", @$.first_line); }
	| Exp COMMA ExpList { childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "ExpList", @$.first_line); }
	;
ExpListEx: ExpList { $$=$1; }
	| %empty { $$ = createEmpty(); }
	;
Args: Exp COMMA Args { 
		childNum = 3; childNodeList[0]=$1; childNodeList[1]=$2; childNodeList[2]=$3; $$=createNode(childNum, childNodeList, "Args", @$.first_line); 
		FieldList* arg = (FieldList*)malloc(sizeof(FieldList)); memset(arg, 0, sizeof(FieldList));
		strcpy(arg->name, $1->expVal);
		arg->type = getExpTypePtr($1, @1.first_line);
		//printf("type %s", TypeToString(arg->type));
		list_pushBack(funcArgs, arg);
	}
    | Exp { 
		childNum = 1; childNodeList[0]=$1; $$=createNode(childNum, childNodeList, "Args", @$.first_line); 
		FieldList* arg = (FieldList*)malloc(sizeof(FieldList)); memset(arg, 0, sizeof(FieldList));
		strcpy(arg->name, $1->expVal);
		arg->type = getExpTypePtr($1, @1.first_line);
		//printf("type %d %d %s\n", type.category, type.primitive, TypeToString(&type));
		list_pushBack(funcArgs, arg);
	}
    ;

// G should be pushed before L
G: %empty {
		$$=createNode(0, childNodeList, "G", @$.first_line); 
		$$->inst = instruction_cnt; 
		//printf("GOTO\n");
		TAC_Goto(spl_instruction+instruction_cnt, ""); instruction_cnt ++;
	}
	;	
	
L: %empty { 
		$$=createNode(0, childNodeList, "L", @$.first_line); 
		$$->inst = instruction_cnt; 
		char LABEL[16]; memset(LABEL, 0, sizeof(LABEL));
		sprintf(LABEL, "label_%d", label_idx++);
		TAC_Label(spl_instruction+instruction_cnt, LABEL); instruction_cnt ++;
	}
	;
%%

void yyerror(char* s){
	printf("%s\n", s);
}

char* TypeToString(Type *type){
	switch (type->category){
		case PRIMITIVE:
			//res = (char*)malloc(sizeof(char)*256);
			if (type->primitive == INT) return "INT";
			if (type->primitive == CHAR) return "CHAR";
			if (type->primitive == FLOAT) return "FLOAT";
			//sprintf(res, "%s", type->name);
			//return res;
			break;
		case ARRAY:
			return ArrayToString(type->array);
			break;
		case STRUCTURE:
			printf("FieldList in Struct: %d\n", list_size(type->structure));
			FieldListToString(type->structure);
			return "struct";
			break;
	}
	return NULL;
}

char* ArrayToString(Array *array){
	char *res = (char*)malloc(sizeof(char)*256);
	sprintf(res, "array baseTypeName=%s size=%d", array->base->name, array->size);
	return res;
}

char *FieldListToString(FieldList* head){
	FieldList* cur = head->next;
	while (cur != NULL){
		printf("Name:%s Type:%s\n", cur->name, TypeToString(cur->type));
		cur = cur->next;
	}
	return NULL;
}

FieldList* validDecDefVar(char *name){
	// Just check current field
	FieldList* var;
	//var = list_findByName(list_getLast(allTmpVarList)->vars, name);
	//if (var != NULL) return var;
	var = list_findByName(tmpList, name);
	if (var != NULL) 
		return var;
	/*
	var = list_getLast(funcList);
	if (var != NULL){
		return list_findByName(var->args, name);
	}
	else 
		return NULL;
	*/
	return NULL;
}

FieldList* validUseVar(char *name){
	// check all fields
	FieldList* var;
	
	var = list_findByName(globalVariableList, name);
	if (var != NULL)
		return var;
	FieldList* cur = allTmpVarList->next;
	while (cur != NULL){
		var = list_findByName(cur->vars, name);
		if (var != NULL) 
			return var;
		cur = cur->next;
	}
	var = list_findByName(tmpList, name);
	if (var != NULL) 
		return var;
	var = list_getLast(funcList);
	if (var != NULL)
		return list_findByName(var->args, name);
	return NULL;
}

int addVar(FieldList* head, struct treeNode* node, int lineno){
	// "ID: "
	if (validDecDefVar(varName) != NULL)
	{
		error_flag = 1;
		printf("Error type 3 at Line %d: Variable '%s' is redefined\n", lineno, node->child[0]->value+4);
		return 1;
	}
	FieldList* newVar = (FieldList*)malloc(sizeof(FieldList)); memset(newVar, 0, sizeof(FieldList));
	strcpy(newVar->name, varName);
	//newVar->type = baseType;
	if (arrayType == NULL){ // not array
		newVar->type = baseType;
	}
	else {
		newVar->type = arrayType;
		// assign space to array
		if (baseType == &INT_TYPE){
			TAC_Dec(spl_instruction+instruction_cnt, varName, 4*varCnt); instruction_cnt++;
		}
	}
	//newVar->type = (arrayType != NULL) ? arrayType : baseType ;
	list_pushBack(head, newVar);
	
	arrayType = NULL; // reset it
	varCnt = 1;
	return 0;
}

int addFuncStruct(FieldList* head, char* funcName, Type *typePtr, int lineno){
	// "ID: "
	if (list_findByName(head, funcName) != NULL){
		error_flag = 1;
		if (!strcmp(head->name, "function"))
			printf("Error type 4 at Line %d: Function '%s' is redefined\n", lineno, funcName);
		if (!strcmp(head->name, "struct"))
			printf("Error type 15 at Line %d: Redefine the same structure type(same name).\n", lineno, funcName);
		return 1;
	}
	
	FieldList* newItem = (FieldList*)malloc(sizeof(FieldList)); memset(newItem, 0, sizeof(FieldList));
	
	newItem->type = typePtr;
	strcpy(newItem->name, funcName); // "ID: "
	
	list_pushBack(head, newItem);
	
	return 0;
}

Type* isValidAssign(struct treeNode *a, struct treeNode *b, int lineno){
	Type *typePtr_a, *typePtr_b;
	typePtr_a = getExpTypePtr(a, lineno);
	typePtr_b = getExpTypePtr(b, lineno);
	if (isSameType(typePtr_a, typePtr_b)){
		return typePtr_a;
	}
	else {
		return &DIFFERENT_TYPE;
	}
}

Type* isValidOperation(struct treeNode *a, struct treeNode *b, char* operation, int lineno){
	Type *typePtr_a, *typePtr_b;
	typePtr_a = getExpTypePtr(a, lineno);
	typePtr_b = getExpTypePtr(b, lineno);
	//printf("%s %s %d\n", TypeToString(typePtr_a), TypeToString(typePtr_b), isSameType(typePtr_a, typePtr_b));
	// "typePtr_a == NULL || typePtr_b == NULL" deal with those conditions 
	// "int a(){ return a(); }" "int a(){ return 0 * a(); }"
	if (typePtr_a == NULL || typePtr_b == NULL || typePtr_a->category == IGNORE || typePtr_b->category == IGNORE) 
		return &IGNORE_TYPE;
	if (typePtr_a->category == PRIMITIVE && (typePtr_a->primitive == INT || typePtr_a->primitive == FLOAT) && isSameType(typePtr_a, typePtr_b)){
		return typePtr_a;
	}
	else {
		error_flag = 1;
		printf("Error type 7 at Line %d: Invalid operation '%s' on non-number variables\n", lineno, operation);
		return &DIFFERENT_TYPE;
	}
}

Type* getExpTypePtr(struct treeNode* node, int lineno){
	switch (node->childNum){
		case 1: // ID INT CHAR FLOAT
			//printf("node value = %s\n", node->child[0]->value);
			switch (node->child[0]->value[0]){
				case 'I': // INT or ID
					if (node->child[0]->value[1] == 'D'){ // ID
						FieldList* var;
						if ((var = validUseVar(node->child[0]->value+4)) != NULL){ //"ID: "
							return var->type;
						}
						else{ // not find this variable, just ignore it
							//printf("Ignore it!\n");
							//printf("node value = %s\n", node->value);
							return &IGNORE_TYPE;
						}
					}
					else { // INT
						return &INT_TYPE;
					}
					break;
				case 'C': // CHAR
					return &CHAR_TYPE;
					break;
				case 'F': // FLOAT
					return &FLOAT_TYPE;
					break;
			}
			break;
		case 2: // only 'MINUS Exp' or 'NOT Exp'
			return getExpTypePtr(node->child[1], lineno);
			break;
		case 3:
			// LP Exp RP
			if (!strcmp(node->child[0]->value, "LP") && !strcmp(node->child[2]->value, "RP")){
				return getExpTypePtr(node->child[1], lineno);
			}
			// ID LP RP
			if (!strcmp(node->child[1]->value, "LP") && !strcmp(node->child[2]->value, "RP")){
				FieldList *func = list_findByName(funcList, node->child[0]->value+4); // "ID: "
				//char *res = TypeToString(func->type);
				//printf("function return type: %s\n", res);
				if (func != NULL) {
					return func->type != NULL ? func->type : &IGNORE_TYPE ; // return itself, may have some bugs during semantic analysis
				}
				else return &IGNORE_TYPE;
			}
			if (!strcmp(node->child[1]->value, "ASSIGN")){ // for ASSIGN operation, just ensure two Exp has same type
				return isValidAssign(node->child[0], node->child[2], lineno);
			}
			else{
				// Exp DOT ID
				//printf("Operation: %s\n", node->child[1]->value);
				if (!strcmp("DOT", node->child[1]->value)){
					Type *typePtr = getExpTypePtr(node->child[0], lineno);
					if (typePtr->category != STRUCTURE){
						error_flag = 1;
						printf("Error type 13 at Line %d: Accessing member of non-structure variable\n", lineno);
						return &IGNORE_TYPE;
					}
					else{
						//printf("StructList: %d %d %d\n", type.category, type.structure, list_size(type.structure));
						//FieldListToString(type.structure);
						FieldList* var = list_findByName(typePtr->structure, node->child[2]->value+4);
						if (var == NULL){
							error_flag = 1;
							printf("Error type 14 at Line %d: Accessing an undefined structure member '%s'\n", lineno, node->child[2]->value+4);
							return &IGNORE_TYPE;
						}
						else {
							return (var->type);
						}
					}
				}
				else{ // Exp Op Exp
					//return &IGNORE_TYPE;
					return isValidOperation(node->child[0], node->child[2], node->child[1]->value, lineno);
				}
			}
			break;
		case 4: 
			// ID LP Args RP
			if (!strcmp(node->child[1]->value, "LP") && !strcmp(node->child[3]->value, "RP")){
				FieldList *func = list_findByName(funcList, node->child[0]->value+4); // "ID: "
				if (func != NULL) {
					return func->type != NULL ? func->type : &IGNORE_TYPE ; // return itself, may have some bugs during semantic analysis
				}
				else return &IGNORE_TYPE;
			}
			//Exp LB Exp RB
			if (!strcmp(node->child[1]->value, "LB") && !strcmp(node->child[3]->value, "RB")){
				Type *typePtr = getExpTypePtr(node->child[2], lineno);
				//printf("Type category: %d primitive %d INT %d BOOL %d childNum %d\n", 
				//	type.category, type.primitive, INT, (type.category == PRIMITIVE && type.primitive == INT), node->child[2]->childNum);
				if (!(typePtr->category == PRIMITIVE && typePtr->primitive == INT)){
					error_flag = 1;
					printf("Error type 12 at Line %d: Array indexing with non-integer type expression\n", lineno);
					return &IGNORE_TYPE;
				}
				typePtr = getExpTypePtr(node->child[0], lineno);
				if (typePtr->category != ARRAY){
					error_flag = 1;
					printf("Error type 10 at Line %d: Applying indexing operator '[]' on non-array type variabless\n", lineno);
					return &IGNORE_TYPE;
				}
				return (typePtr->array->base);
			}
			break;
	}
	//printf("getExpTypePtr() return NULL\ns");
	return NULL;
}

Type* parseSpecifier(struct treeNode* node){
	node = node->child[0];
	if (!memcmp(node->value, "TYPE", 4)){
		// "TYPE :"
		switch (*(node->value+6)){
			case 'i':
				return &INT_TYPE;
				break;
			case 'f':
				return &FLOAT_TYPE;
				break;
			case 'c':
				return &CHAR_TYPE;
				break;
		}
	}
	return NULL;
}

void backPatch(int patchIdx, int inst){
	if (!strcmp(spl_instruction[patchIdx].seg[0], "IF")){
		strcpy(spl_instruction[patchIdx].seg[5], spl_instruction[inst].seg[1]);
	}
	if (!strcmp(spl_instruction[patchIdx].seg[0], "GOTO")){
		strcpy(spl_instruction[patchIdx].seg[1], spl_instruction[inst].seg[1]);
	}
}

void backPatchList(int *list, int inst){
	//printf("backPatching...\n");
	int patchIdx;
	while ((patchIdx = *list) != 0){
		backPatch(patchIdx, inst);
		list ++;
	}
}

int main(int argc, char** args){
	//for (int i = 0 ; i < argc ; i ++)
	//	printf("%d %s\n", i, args[i]);
	
	// input
	freopen(args[1], "r", stdin);
	
	// output
	char outputPath[256];
	strcpy(outputPath, args[1]);
	strcpy(outputPath+strlen(outputPath)-3, "ir");
	//printf("OutputPath = %s\n", outputPath);
	freopen(outputPath, "w", stdout);
	
	globalVariableList = list_init();
	globalStructList = list_init();
	
	tmpList = list_init();
	allTmpVarList = list_init();
	
	funcList = list_init(); strcpy(funcList->name, "function");
	
	retList = list_init(); strcpy(retList->name, "return");
	funcArgs = list_init(); strcpy(funcArgs->name, "functionArguments");
	
	structList = list_init(); strcpy(structList->name, "struct");
	
	addFuncStruct(funcList, "read", &INT_TYPE, 0);
	addFuncStruct(funcList, "write", &INT_TYPE, 0);
	FieldList* arg = (FieldList*)malloc(sizeof(FieldList)); memset(arg, 0, sizeof(FieldList));
	arg->type = &INT_TYPE;
	FieldList* curFunc = list_getLast(funcList);
	curFunc->args = (FieldList*)malloc(sizeof(FieldList));
	list_pushBack(curFunc->args, arg); 
	
	//printf("Parsing...\n");
    yyparse();
	
	//printf("instruction_cnt = %d\n", instruction_cnt);
	optimizeTAC(spl_instruction, instruction_cnt);
	for (int i = 0 ; i < instruction_cnt ; i ++){
		if (!strcmp(spl_instruction[i].seg[0], "NOP")) continue;
		printTAC(spl_instruction+i); 
	}
	
	//printf("error_flag = %d\n", error_flag);
	
	fclose(stdin);
	fclose(stdout);
}