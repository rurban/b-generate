#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef PERL_OBJECT
#undef PL_op_name
#undef PL_opargs 
#undef PL_op_desc
#define PL_op_name (get_op_names())
#define PL_opargs (get_opargs())
#define PL_op_desc (get_op_descs())
#endif

static char *svclassnames[] = {
    "B::NULL",
    "B::IV",
    "B::NV",
    "B::RV",
    "B::PV",
    "B::PVIV",
    "B::PVNV",
    "B::PVMG",
    "B::BM",
    "B::PVLV",
    "B::AV",
    "B::HV",
    "B::CV",
    "B::GV",
    "B::FM",
    "B::IO",
};

typedef enum {
    OPc_NULL,	/* 0 */
    OPc_BASEOP,	/* 1 */
    OPc_UNOP,	/* 2 */
    OPc_BINOP,	/* 3 */
    OPc_LOGOP,	/* 4 */
    OPc_LISTOP,	/* 5 */
    OPc_PMOP,	/* 6 */
    OPc_SVOP,	/* 7 */
    OPc_PADOP,	/* 8 */
    OPc_PVOP,	/* 9 */
    OPc_CVOP,	/* 10 */
    OPc_LOOP,	/* 11 */
    OPc_COP	/* 12 */
} opclass;

static char *opclassnames[] = {
    "B::NULL",
    "B::OP",
    "B::UNOP",
    "B::BINOP",
    "B::LOGOP",
    "B::LISTOP",
    "B::PMOP",
    "B::SVOP",
    "B::PADOP",
    "B::PVOP",
    "B::CVOP",
    "B::LOOP",
    "B::COP"	
};

static int walkoptree_debug = 0;	/* Flag for walkoptree debug hook */

static SV *specialsv_list[6];

static SV *
make_sv_object(pTHX_ SV *arg, SV *sv)
{
    char *type = 0;
    IV iv;

    for (iv = 0; iv < sizeof(specialsv_list)/sizeof(SV*); iv++) {
    if (sv == specialsv_list[iv]) {
        type = "B::SPECIAL";
        break;
    }
    }
    if (!type) {
    type = svclassnames[SvTYPE(sv)];
    iv = PTR2IV(sv);
    }
    sv_setiv(newSVrv(arg, type), iv);
    return arg;
}

static I32
op_name_to_num(SV * name)
{
    char *s;
    int i =0;
    if (SvIOK(name) && SvIV(name) >= 0 && SvIV(name) < OP_max)
        return SvIV(name);

    for (s = PL_op_name[i]; s; s = PL_op_name[++i]) {
        if (strEQ(s, SvPV_nolen(name)))
            return i;
    }
    croak("No such op \"%s\"", SvPV_nolen(name));
    return -1;
}

static opclass
cc_opclass(pTHX_ OP *o)
{
    if (!o)
	return OPc_NULL;

    if (o->op_type == 0)
	return (o->op_flags & OPf_KIDS) ? OPc_UNOP : OPc_BASEOP;

    if (o->op_type == OP_SASSIGN)
	return ((o->op_private & OPpASSIGN_BACKWARDS) ? OPc_UNOP : OPc_BINOP);

#ifdef USE_ITHREADS
    if (o->op_type == OP_GV || o->op_type == OP_GVSV || o->op_type == OP_AELEMFAST)
	return OPc_PADOP;
#endif

    switch (PL_opargs[o->op_type] & OA_CLASS_MASK) {
    case OA_BASEOP:
	return OPc_BASEOP;

    case OA_UNOP:
	return OPc_UNOP;

    case OA_BINOP:
	return OPc_BINOP;

    case OA_LOGOP:
	return OPc_LOGOP;

    case OA_LISTOP:
	return OPc_LISTOP;

    case OA_PMOP:
	return OPc_PMOP;

    case OA_SVOP:
	return OPc_SVOP;

    case OA_PADOP:
	return OPc_PADOP;

    case OA_PVOP_OR_SVOP:
        /*
         * Character translations (tr///) are usually a PVOP, keeping a 
         * pointer to a table of shorts used to look up translations.
         * Under utf8, however, a simple table isn't practical; instead,
         * the OP is an SVOP, and the SV is a reference to a swash
         * (i.e., an RV pointing to an HV).
         */
	return (o->op_private & (OPpTRANS_TO_UTF|OPpTRANS_FROM_UTF))
		? OPc_SVOP : OPc_PVOP;

    case OA_LOOP:
	return OPc_LOOP;

    case OA_COP:
	return OPc_COP;

    case OA_BASEOP_OR_UNOP:
	/*
	 * UNI(OP_foo) in toke.c returns token UNI or FUNC1 depending on
	 * whether parens were seen. perly.y uses OPf_SPECIAL to
	 * signal whether a BASEOP had empty parens or none.
	 * Some other UNOPs are created later, though, so the best
	 * test is OPf_KIDS, which is set in newUNOP.
	 */
	return (o->op_flags & OPf_KIDS) ? OPc_UNOP : OPc_BASEOP;

    case OA_FILESTATOP:
	/*
	 * The file stat OPs are created via UNI(OP_foo) in toke.c but use
	 * the OPf_REF flag to distinguish between OP types instead of the
	 * usual OPf_SPECIAL flag. As usual, if OPf_KIDS is set, then we
	 * return OPc_UNOP so that walkoptree can find our children. If
	 * OPf_KIDS is not set then we check OPf_REF. Without OPf_REF set
	 * (no argument to the operator) it's an OP; with OPf_REF set it's
	 * an SVOP (and op_sv is the GV for the filehandle argument).
	 */
	return ((o->op_flags & OPf_KIDS) ? OPc_UNOP :
#ifdef USE_ITHREADS
		(o->op_flags & OPf_REF) ? OPc_PADOP : OPc_BASEOP);
#else
		(o->op_flags & OPf_REF) ? OPc_SVOP : OPc_BASEOP);
#endif
    case OA_LOOPEXOP:
	/*
	 * next, last, redo, dump and goto use OPf_SPECIAL to indicate that a
	 * label was omitted (in which case it's a BASEOP) or else a term was
	 * seen. In this last case, all except goto are definitely PVOP but
	 * goto is either a PVOP (with an ordinary constant label), an UNOP
	 * with OPf_STACKED (with a non-constant non-sub) or an UNOP for
	 * OP_REFGEN (with goto &sub) in which case OPf_STACKED also seems to
	 * get set.
	 */
	if (o->op_flags & OPf_STACKED)
	    return OPc_UNOP;
	else if (o->op_flags & OPf_SPECIAL)
	    return OPc_BASEOP;
	else
	    return OPc_PVOP;
    }
    warn("can't determine class of operator %s, assuming BASEOP\n",
	 PL_op_name[o->op_type]);
    return OPc_BASEOP;
}

static char *
cc_opclassname(pTHX_ OP *o)
{
    return opclassnames[cc_opclass(aTHX_ o)];
}

static OP * 
SVtoO(SV* sv) {
    if (SvROK(sv)) {
        IV tmp = SvIV((SV*)SvRV(sv));
        return INT2PTR(OP*,tmp);
    }
    else
        croak("Argument is not a reference");
    return 0; /* Not reached */
}

typedef OP	*B__OP;
typedef UNOP	*B__UNOP;
typedef BINOP	*B__BINOP;
typedef LOGOP	*B__LOGOP;
typedef LISTOP	*B__LISTOP;
typedef PMOP	*B__PMOP;
typedef SVOP	*B__SVOP;
typedef PADOP	*B__PADOP;
typedef PVOP	*B__PVOP;
typedef LOOP	*B__LOOP;
typedef COP	*B__COP;

typedef SV	*B__SV;
typedef SV	*B__IV;
typedef SV	*B__PV;
typedef SV	*B__NV;
typedef SV	*B__PVMG;
typedef SV	*B__PVLV;
typedef SV	*B__BM;
typedef SV	*B__RV;
typedef AV	*B__AV;
typedef HV	*B__HV;
typedef CV	*B__CV;
typedef GV	*B__GV;
typedef IO	*B__IO;

typedef MAGIC	*B__MAGIC;

MODULE = B::Generate	PACKAGE = B	PREFIX = B_

void
B_fudge()
    CODE:
        SSCHECK(2);
        SSPUSHPTR((SV*)PL_comppad);  
        SSPUSHINT(SAVEt_COMPPAD);

B::OP
B_main_root(...)
    PROTOTYPE: ;$
    CODE:
        if (items > 0)
            PL_main_root = SVtoO(ST(0));
        RETVAL = PL_main_root;
    OUTPUT:
        RETVAL
    
B::OP
B_main_start(...)
    PROTOTYPE: ;$
    CODE:
        if (items > 0)
            PL_main_start = SVtoO(ST(0));
        RETVAL = PL_main_start;
    OUTPUT:
        RETVAL

#define OP_desc(o)	PL_op_desc[o->op_type]

MODULE = B::Generate	PACKAGE = B::OP		PREFIX = OP_

B::OP
OP_next(o, ...)
	B::OP		o
    CODE:
        if (items > 1)
            o->op_next = SVtoO(ST(1));
        RETVAL = o->op_next;
    OUTPUT:
        RETVAL

B::OP
OP_sibling(o, ...)
	B::OP		o
    CODE:
        if (items > 1)
            o->op_sibling = SVtoO(ST(1));
        RETVAL = o->op_sibling;
    OUTPUT:
        RETVAL

char * 
OP_ppaddr(o)
	B::OP		o
    PREINIT:
	int i;
	SV *sv = sv_newmortal();
    CODE:
	sv_setpvn(sv, "PL_ppaddr[OP_", 13);
	sv_catpv(sv, PL_op_name[o->op_type]);
	for (i=13; i<SvCUR(sv); ++i)
	    SvPVX(sv)[i] = toUPPER(SvPVX(sv)[i]);
	sv_catpv(sv, "]");
	ST(0) = sv;

char *
OP_desc(o)
	B::OP		o

PADOFFSET
OP_targ(o, ...)
	B::OP		o
    CODE:
        if (items > 1)
            o->op_targ = (PADOFFSET)SvIV(ST(1));
        RETVAL = o->op_targ;
    OUTPUT:
        RETVAL

U16
OP_type(o, ...)
	B::OP		o
    CODE:
        if (items > 1)
            o->op_type = (U16)SvIV(ST(1));
        RETVAL = o->op_type;
    OUTPUT:
        RETVAL

U16
OP_seq(o, ...)
	B::OP		o
    CODE:
        if (items > 1)
            o->op_seq = (U16)SvIV(ST(1));
        RETVAL = o->op_seq;
    OUTPUT:
        RETVAL

U8
OP_flags(o, ...)
	B::OP		o
    CODE:
        if (items > 1)
            o->op_flags = (U8)SvIV(ST(1));
        RETVAL = o->op_flags;
    OUTPUT:
        RETVAL

U8
OP_private(o, ...)
	B::OP		o
    CODE:
        if (items > 1)
            o->op_private = (U8)SvIV(ST(1));
        RETVAL = o->op_private;
    OUTPUT:
        RETVAL

void
OP_dump(o)
    B::OP o
    CODE:
        op_dump(o);

void
OP_clean(o)
    B::OP o
    CODE:
        if (o == PL_main_root)
            o->op_next = Nullop;

void
OP_new(class, type, flags)
    SV * class
    SV * type
    I32 flags
    SV** sparepad = NO_INIT
    OP *o = NO_INIT
    OP *saveop = NO_INIT
    I32 typenum = NO_INIT
    CODE:
        sparepad = PL_curpad;
        saveop = PL_op;
        PL_curpad = AvARRAY(PL_comppad);
        o = newOP(op_name_to_num(type), flags);
        PL_curpad = sparepad;
        PL_op = saveop;
	    ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::OP"), PTR2IV(o));

void
OP_newstate(class, flags, label, oldo)
    SV * class
    I32 flags
    char * label
    B::OP oldo
    SV** sparepad = NO_INIT
    OP *o = NO_INIT
    OP *saveop = NO_INIT
    CODE:
        sparepad = PL_curpad;
        saveop = PL_op;
        PL_curpad = AvARRAY(PL_comppad);
        o = newSTATEOP(flags, label, oldo);
        PL_curpad = sparepad;
        PL_op = saveop;
	    ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::LISTOP"), PTR2IV(o));

MODULE = B::Generate	PACKAGE = B::UNOP		PREFIX = UNOP_

B::OP 
UNOP_first(o, ...)
	B::UNOP	o
    CODE:
        if (items > 1)
            o->op_first = SVtoO(ST(1));
        RETVAL = o->op_first;
    OUTPUT:
        RETVAL
    
void
UNOP_new(class, type, flags, sv_first)
    SV * class
    SV * type
    I32 flags
    SV * sv_first
    OP *first = NO_INIT
    OP *o = NO_INIT
    CODE:
        if (SvROK(sv_first)) {
            if (!sv_derived_from(sv_first, "B::OP"))
                Perl_croak(aTHX_ "Reference 'first' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_first));
                first = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_first))
            Perl_croak(aTHX_ 
            "'first' argument to B::UNOP->new should be a B::OP object or a false value");
        else
            first = Nullop;

        {
        SV**sparepad = PL_curpad;
        OP* saveop = PL_op;
        PL_curpad = AvARRAY(PL_comppad);
        o = newUNOP(op_name_to_num(type), flags, first);
        PL_curpad = sparepad;
        PL_op = saveop;
        }
	    ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::UNOP"), PTR2IV(o));

MODULE = B::Generate	PACKAGE = B::BINOP		PREFIX = BINOP_

B::OP
BINOP_last(o,...)
	B::BINOP	o
    CODE:
        if (items > 1)
            o->op_last = SVtoO(ST(1));
        RETVAL = o->op_last;
    OUTPUT:
        RETVAL

void
BINOP_new(class, type, flags, sv_first, sv_last)
    SV * class
    SV * type
    I32 flags
    SV * sv_first
    SV * sv_last
    OP *first = NO_INIT
    OP *last = NO_INIT
    OP *o = NO_INIT
    CODE:
        if (SvROK(sv_first)) {
            if (!sv_derived_from(sv_first, "B::OP"))
                Perl_croak(aTHX_ "Reference 'first' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_first));
                first = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_first))
            Perl_croak(aTHX_ 
            "'first' argument to B::UNOP->new should be a B::OP object or a false value");
        else
            first = Nullop;

        if (SvROK(sv_last)) {
            if (!sv_derived_from(sv_last, "B::OP"))
                Perl_croak(aTHX_ "Reference 'last' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_last));
                last = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_last))
            Perl_croak(aTHX_ 
            "'last' argument to B::BINOP->new should be a B::OP object or a false value");
        else
            last = Nullop;

        {
        SV**sparepad = PL_curpad;
        OP* saveop = PL_op;
        PL_curpad = AvARRAY(PL_comppad);
        o = newBINOP(op_name_to_num(type), flags, first, last);
        PL_curpad = sparepad;
        PL_op = saveop;
        }
	    ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::BINOP"), PTR2IV(o));

MODULE = B::Generate	PACKAGE = B::LOGOP		PREFIX = LOGOP_

B::OP
LOGOP_other(o,...)
	B::LOGOP	o
    CODE:
        if (items > 1)
            o->op_other = SVtoO(ST(1));
        RETVAL = o->op_other;
    OUTPUT:
        RETVAL

void
LOGOP_new(class, type, flags, sv_first, sv_other)
    SV * class
    SV * type
    I32 flags
    SV * sv_first
    SV * sv_other
    OP *first = NO_INIT
    OP *other = NO_INIT
    OP *o = NO_INIT
    CODE:
        if (SvROK(sv_first)) {
            if (!sv_derived_from(sv_first, "B::OP"))
                Perl_croak(aTHX_ "Reference 'first' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_first));
                first = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_first))
            Perl_croak(aTHX_ 
            "'first' argument to B::UNOP->new should be a B::OP object or a false value");
        else
            first = Nullop;

        if (SvROK(sv_other)) {
            if (!sv_derived_from(sv_other, "B::OP"))
                Perl_croak(aTHX_ "Reference 'other' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_other));
                other = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_other))
            Perl_croak(aTHX_ 
            "'other' argument to B::BINOP->new should be a B::OP object or a false value");
        else
            other = Nullop;

        {
        SV**sparepad = PL_curpad;
        OP *saveop = PL_op;
        PL_curpad = AvARRAY(PL_comppad);
        o = newBINOP(op_name_to_num(type), flags, first, other);
        PL_curpad = sparepad;
        PL_op = saveop;
        }
	    ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::LOGOP"), PTR2IV(o));

MODULE = B::Generate	PACKAGE = B::LISTOP		PREFIX = LISTOP_

U32
LISTOP_children(o, ...)
	B::LISTOP	o
    CODE:
        if (items > 1)
            o->op_children = (U32)SvIV(ST(1));
        RETVAL = o->op_children;
    OUTPUT:
        RETVAL

void
LISTOP_new(class, type, flags, sv_first, sv_last)
    SV * class
    SV * type
    I32 flags
    SV * sv_first
    SV * sv_last
    OP *first = NO_INIT
    OP *last = NO_INIT
    OP *o = NO_INIT
    CODE:
        if (SvROK(sv_first)) {
            if (!sv_derived_from(sv_first, "B::OP"))
                Perl_croak(aTHX_ "Reference 'first' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_first));
                first = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_first))
            Perl_croak(aTHX_ 
            "'first' argument to B::UNOP->new should be a B::OP object or a false value");
        else
            first = Nullop;

        if (SvROK(sv_last)) {
            if (!sv_derived_from(sv_last, "B::OP"))
                Perl_croak(aTHX_ "Reference 'last' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_last));
                last = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_last))
            Perl_croak(aTHX_ 
            "'last' argument to B::BINOP->new should be a B::OP object or a false value");
        else
            last = Nullop;

        {
        SV**sparepad = PL_curpad;
        OP* saveop   = PL_op;
        PL_curpad = AvARRAY(PL_comppad);
        o = newBINOP(op_name_to_num(type), flags, first, last);
        PL_curpad = sparepad;
        PL_op = saveop;
        }
	    ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::LISTOP"), PTR2IV(o));

MODULE = B::Generate	PACKAGE = B::LOGOP		PREFIX = LOGOP_

#define PMOP_pmreplroot(o)	o->op_pmreplroot
#define PMOP_pmnext(o)		o->op_pmnext
#define PMOP_pmregexp(o)	o->op_pmregexp
#define PMOP_pmflags(o)		o->op_pmflags
#define PMOP_pmpermflags(o)	o->op_pmpermflags

MODULE = B::Generate	PACKAGE = B::PMOP		PREFIX = PMOP_

void
PMOP_pmreplroot(o)
	B::PMOP		o
	OP *		root = NO_INIT
    CODE:
	ST(0) = sv_newmortal();
	root = o->op_pmreplroot;
	/* OP_PUSHRE stores an SV* instead of an OP* in op_pmreplroot */
	if (o->op_type == OP_PUSHRE) {
	    sv_setiv(newSVrv(ST(0), root ?
			     svclassnames[SvTYPE((SV*)root)] : "B::SV"),
		     PTR2IV(root));
	}
	else {
	    sv_setiv(newSVrv(ST(0), cc_opclassname(aTHX_ root)), PTR2IV(root));
	}

B::OP
PMOP_pmreplstart(o, ...)
	B::PMOP		o
    CODE:
        if (items > 1)
            o->op_pmreplstart = SVtoO(ST(1));
        RETVAL = o->op_pmreplstart;
    OUTPUT:
        RETVAL

B::PMOP
PMOP_pmnext(o, ...)
	B::PMOP		o
    CODE:
        if (items > 1)
            o->op_pmnext = (PMOP*)SVtoO(ST(1));
        RETVAL = o->op_pmnext;
    OUTPUT:
        RETVAL

U16
PMOP_pmflags(o)
	B::PMOP		o

U16
PMOP_pmpermflags(o)
	B::PMOP		o

void
PMOP_precomp(o)
	B::PMOP		o
	REGEXP *	rx = NO_INIT
    CODE:
	ST(0) = sv_newmortal();
	rx = o->op_pmregexp;
	if (rx)
	    sv_setpvn(ST(0), rx->precomp, rx->prelen);

#define SVOP_sv(o)     cSVOPo->op_sv
#define SVOP_gv(o)     ((GV*)cSVOPo->op_sv)

MODULE = B::Generate	PACKAGE = B::SVOP		PREFIX = SVOP_

B::SV
SVOP_sv(o, ...)
	B::SVOP	o
    CODE:
        if (items > 1)
            cSVOPo->op_sv = newSVsv(ST(1));
        RETVAL = cSVOPo->op_sv;
    OUTPUT:
        RETVAL

B::GV
SVOP_gv(o)
	B::SVOP	o

void
SVOP_new(class, type, flags, sv)
    SV * class
    SV * type
    I32 flags
    SV * sv
    SV** sparepad = NO_INIT
    OP *o = NO_INIT
    OP *saveop = NO_INIT
    SV* param = NO_INIT
    I32 typenum = NO_INIT
    CODE:
        sparepad = PL_curpad;
        PL_curpad = AvARRAY(PL_comppad);
        saveop = PL_op;
        typenum = op_name_to_num(type); /* XXX More classes here! */
        if (typenum == OP_GVSV) {
            if (*(SvPV_nolen(sv)) == '$') 
                param = (SV*)gv_fetchpv(SvPVX(sv)+1, TRUE, SVt_PV);
            else
            Perl_croak(aTHX_ 
            "First character to GVSV was not dollar");
        } else
            param = newSVsv(sv);
        o = newSVOP(op_name_to_num(type), flags, param);
        PL_curpad = sparepad;
	    ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::SVOP"), PTR2IV(o));
        PL_op = saveop;

#define PADOP_padix(o)	o->op_padix
#define PADOP_sv(o)	(o->op_padix ? PL_curpad[o->op_padix] : Nullsv)
#define PADOP_gv(o)	((o->op_padix \
			  && SvTYPE(PL_curpad[o->op_padix]) == SVt_PVGV) \
			 ? (GV*)PL_curpad[o->op_padix] : Nullgv)

MODULE = B::Generate	PACKAGE = B::PADOP		PREFIX = PADOP_

PADOFFSET
PADOP_padix(o)
	B::PADOP o

B::SV
PADOP_sv(o)
	B::PADOP o

B::GV
PADOP_gv(o)
	B::PADOP o

MODULE = B::Generate	PACKAGE = B::PVOP		PREFIX = PVOP_

void
PVOP_pv(o)
	B::PVOP	o
    CODE:
	/*
	 * OP_TRANS uses op_pv to point to a table of 256 shorts
	 * whereas other PVOPs point to a null terminated string.
	 */
	ST(0) = sv_2mortal(newSVpv(o->op_pv, (o->op_type == OP_TRANS) ?
				   256 * sizeof(short) : 0));

MODULE = B::Generate	PACKAGE = B::LOOP		PREFIX = LOOP_

B::OP
LOOP_redoop(o, ...)
	B::LOOP	o
    CODE:
        if (items > 1)
            o->op_redoop = SVtoO(ST(1));
        RETVAL = o->op_redoop;
    OUTPUT:
        RETVAL

B::OP
LOOP_nextop(o, ...)
	B::LOOP	o
    CODE:
        if (items > 1)
            o->op_nextop = SVtoO(ST(1));
        RETVAL = o->op_nextop;
    OUTPUT:
        RETVAL

B::OP
LOOP_lastop(o, ...)
	B::LOOP	o
    CODE:
        if (items > 1)
            o->op_lastop = SVtoO(ST(1));
        RETVAL = o->op_lastop;
    OUTPUT:
        RETVAL

#define COP_label(o)	o->cop_label
#define COP_stashpv(o)	CopSTASHPV(o)
#define COP_stash(o)	CopSTASH(o)
#define COP_file(o)	CopFILE(o)
#define COP_cop_seq(o)	o->cop_seq
#define COP_arybase(o)	o->cop_arybase
#define COP_line(o)	CopLINE(o)
#define COP_warnings(o)	o->cop_warnings

MODULE = B::Generate	PACKAGE = B::COP		PREFIX = COP_

char *
COP_label(o)
	B::COP	o

char *
COP_stashpv(o)
	B::COP	o

B::HV
COP_stash(o)
	B::COP	o

char *
COP_file(o)
	B::COP	o

U32
COP_cop_seq(o)
	B::COP	o

I32
COP_arybase(o)
	B::COP	o

U16
COP_line(o)
	B::COP	o

B::SV
COP_warnings(o)
	B::COP	o

B::COP
COP_new(class, flags, name, sv_first)
    SV * class
    char * name
    I32 flags
    SV * sv_first
    OP *first = NO_INIT
    OP *o = NO_INIT
    CODE:
        if (SvROK(sv_first)) {
            if (!sv_derived_from(sv_first, "B::OP"))
                Perl_croak(aTHX_ "Reference 'first' was not a B::OP object");
            else {
                IV tmp = SvIV((SV*)SvRV(sv_first));
                first = INT2PTR(OP*, tmp);
            }
        } else if (SvTRUE(sv_first))
            Perl_croak(aTHX_ 
            "'first' argument to B::COP->new should be a B::OP object or a false value");
        else
            first = Nullop;

        {
        SV**sparepad = PL_curpad;
        OP* saveop = PL_op;
        PL_curpad = AvARRAY(PL_comppad);
        o = newSTATEOP(flags, name, first);
        PL_curpad = sparepad;
        PL_op = saveop;
        }
	    ST(0) = sv_newmortal();
        sv_setiv(newSVrv(ST(0), "B::COP"), PTR2IV(o));

MODULE = B::Generate  PACKAGE = B::SV  PREFIX = Sv

SV*
Svsv(sv)
    B::SV   sv
    CODE:
        RETVAL = newSVsv(sv);
    OUTPUT:
        RETVAL

void*
Svdump(sv)
    B::SV   sv
    CODE:
        sv_dump(sv);

U32
SvFLAGS(sv, ...)
    B::SV   sv
    CODE:
        if (items > 1)
            sv->sv_flags = SvIV(ST(1));
        RETVAL = SvFLAGS(sv);
    OUTPUT:
        RETVAL

