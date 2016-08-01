#ifndef TARANTOOL_BOX_TUPLE_H_INCLUDED
#define TARANTOOL_BOX_TUPLE_H_INCLUDED
/*
 * Copyright 2010-2016, Tarantool AUTHORS, please see AUTHORS file.
 *
 * Redistribution and use in source and binary forms, with or
 * without modification, are permitted provided that the following
 * conditions are met:
 *
 * 1. Redistributions of source code must retain the above
 *    copyright notice, this list of conditions and the
 *    following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY <COPYRIGHT HOLDER> ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * <COPYRIGHT HOLDER> OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 * THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
#include "trivia/util.h"

#include "tuple_format.h"

#if defined(__cplusplus)
extern "C" {
#endif /* defined(__cplusplus) */

/** \cond public */

typedef struct tuple_format box_tuple_format_t;

/**
 * Tuple Format.
 *
 * Each Tuple has associated format (class). Default format is used to
 * create tuples which are not attach to any particular space.
 */
box_tuple_format_t *
box_tuple_format_default(void);

/**
 * Tuple
 */
typedef struct tuple box_tuple_t;

/**
 * Allocate and initialize a new tuple from a raw MsgPack Array data.
 *
 * \param format tuple format.
 * Use box_tuple_format_default() to create space-independent tuple.
 * \param data tuple data in MsgPack Array format ([field1, field2, ...]).
 * \param end the end of \a data
 * \retval NULL on out of memory
 * \retval tuple otherwise
 * \pre data, end is valid MsgPack Array
 * \sa \code box.tuple.new(data) \endcode
 */
box_tuple_t *
box_tuple_new(box_tuple_format_t *format, const char *data, const char *end);

/**
 * Increase the reference counter of tuple.
 *
 * Tuples are reference counted. All functions that return tuples guarantee
 * that the last returned tuple is refcounted internally until the next
 * call to API function that yields or returns another tuple.
 *
 * You should increase the reference counter before taking tuples for long
 * processing in your code. Such tuples will not be garbage collected even
 * if another fiber remove they from space. After processing please
 * decrement the reference counter using box_tuple_unref(), otherwise the
 * tuple will leak.
 *
 * \param tuple a tuple
 * \retval -1 on error (check box_error_last())
 * \retval 0 on success
 * \sa box_tuple_unref()
 */
int
box_tuple_ref(box_tuple_t *tuple);

/**
 * Decrease the reference counter of tuple.
 *
 * \param tuple a tuple
 * \sa box_tuple_ref()
 */
void
box_tuple_unref(box_tuple_t *tuple);

/**
 * Return the number of fields in tuple (the size of MsgPack Array).
 * \param tuple a tuple
 */
uint32_t
box_tuple_field_count(const box_tuple_t *tuple);

/**
 * Return the number of bytes used to store internal tuple data (MsgPack Array).
 * \param tuple a tuple
 */
size_t
box_tuple_bsize(const box_tuple_t *tuple);

/**
 * Dump raw MsgPack data to the memory byffer \a buf of size \a size.
 *
 * Store tuple fields in the memory buffer.
 * \retval -1 on error.
 * \retval number of bytes written on success.
 * Upon successful return, the function returns the number of bytes written.
 * If buffer size is not enough then the return value is the number of bytes
 * which would have been written if enough space had been available.
 */
ssize_t
box_tuple_to_buf(const box_tuple_t *tuple, char *buf, size_t size);

/**
 * Return the associated format.
 * \param tuple tuple
 * \return tuple_format
 */
box_tuple_format_t *
box_tuple_format(const box_tuple_t *tuple);

/**
 * Return the raw tuple field in MsgPack format.
 *
 * The buffer is valid until next call to box_tuple_* functions.
 *
 * \param tuple a tuple
 * \param field_id zero-based index in MsgPack array.
 * \retval NULL if i >= box_tuple_field_count(tuple)
 * \retval msgpack otherwise
 */
const char *
box_tuple_field(const box_tuple_t *tuple, uint32_t field_id);

/**
 * Tuple iterator
 */
typedef struct tuple_iterator box_tuple_iterator_t;

/**
 * Allocate and initialize a new tuple iterator. The tuple iterator
 * allow to iterate over fields at root level of MsgPack array.
 *
 * Example:
 * \code
 * box_tuple_iterator *it = box_tuple_iterator(tuple);
 * if (it == NULL) {
 *      // error handling using box_error_last()
 * }
 * const char *field;
 * while (field = box_tuple_next(it)) {
 *      // process raw MsgPack data
 * }
 *
 * // rewind iterator to first position
 * box_tuple_rewind(it);
 * assert(box_tuple_position(it) == 0);
 *
 * // rewind iterator to first position
 * field = box_tuple_seek(it, 3);
 * assert(box_tuple_position(it) == 4);
 *
 * box_iterator_free(it);
 * \endcode
 *
 * \post box_tuple_position(it) == 0
 */
box_tuple_iterator_t *
box_tuple_iterator(box_tuple_t *tuple);

/**
 * Destroy and free tuple iterator
 */
void
box_tuple_iterator_free(box_tuple_iterator_t *it);

/**
 * Return zero-based next position in iterator.
 * That is, this function return the field id of field that will be
 * returned by the next call to box_tuple_next(it). Returned value is zero
 * after initialization or rewind and box_tuple_field_count(tuple)
 * after the end of iteration.
 *
 * \param it tuple iterator
 * \returns position.
 */
uint32_t
box_tuple_position(box_tuple_iterator_t *it);

/**
 * Rewind iterator to the initial position.
 *
 * \param it tuple iterator
 * \post box_tuple_position(it) == 0
 */
void
box_tuple_rewind(box_tuple_iterator_t *it);

/**
 * Seek the tuple iterator.
 *
 * The returned buffer is valid until next call to box_tuple_* API.
 * Requested field_no returned by next call to box_tuple_next(it).
 *
 * \param it tuple iterator
 * \param field_no field no - zero-based position in MsgPack array.
 * \post box_tuple_position(it) == field_no if returned value is not NULL
 * \post box_tuple_position(it) == box_tuple_field_count(tuple) if returned
 * value is NULL.
 */
const char *
box_tuple_seek(box_tuple_iterator_t *it, uint32_t field_no);

/**
 * Return the next tuple field from tuple iterator.
 * The returned buffer is valid until next call to box_tuple_* API.
 *
 * \param it tuple iterator.
 * \retval NULL if there are no more fields.
 * \retval MsgPack otherwise
 * \pre box_tuple_position(it) is zerod-based id of returned field
 * \post box_tuple_position(it) == box_tuple_field_count(tuple) if returned
 * value is NULL.
 */
const char *
box_tuple_next(box_tuple_iterator_t *it);

box_tuple_t *
box_tuple_update(const box_tuple_t *tuple, const char *expr, const
		 char *expr_end);

box_tuple_t *
box_tuple_upsert(const box_tuple_t *tuple, const char *expr, const
		 char *expr_end);

char *
box_tuple_extract_key(const box_tuple_t *tuple, uint32_t space_id,
	uint32_t index_id, uint32_t *key_size);

/** \endcond public */

/**
 * @brief Compare two tuple fields using using field type definition
 * @param field_a field
 * @param field_b field
 * @param field_type field type definition
 * @retval 0  if field_a == field_b
 * @retval <0 if field_a < field_b
 * @retval >0 if field_a > field_b
 */
int
tuple_compare_field(const char *field_a, const char *field_b,
		    enum field_type type);

#if defined(__cplusplus)
} /* extern "C" */

#include "key_def.h" /* for enum field_type */
#include "tuple_update.h"
#include "errinj.h"

enum { TUPLE_REF_MAX = UINT16_MAX };

/** Common quota for tuples and indexes */
extern struct quota memtx_quota;
/** Tuple allocator */
extern struct small_alloc memtx_alloc;
/** Tuple slab arena */
extern struct slab_arena memtx_arena;

/**
 * An atom of Tarantool storage. Represents MsgPack Array.
 */
struct PACKED tuple
{
	/*
	 * sic: the header of the tuple is used
	 * to store a free list pointer in smfree_delayed.
	 * Please don't change it without understanding
	 * how smfree_delayed and snapshotting COW works.
	 */
	/** snapshot generation version */
	uint32_t version;
	/** reference counter */
	uint16_t refs;
	/** format identifier */
	uint16_t format_id;
	/** length of the variable part of the tuple */
	uint32_t bsize;
	/**
	 * Fields can have variable length, and thus are packed
	 * into a contiguous byte array. Each field is prefixed
	 * with BER-packed field length.
	 */
	char data[0];
};

/**
 * Create a new tuple from a sequence of MsgPack encoded fields.
 * tuple->refs is 0.
 *
 * Throws an exception if tuple format is incorrect.
 *
 * \sa box_tuple_new()
 */
struct tuple *
tuple_new(struct tuple_format *format, const char *data, const char *end);

/**
 * Allocate a tuple
 * It's similar to tuple_new, but does not set tuple data and thus does not
 * initialize field offsets.
 *
 * After tuple_alloc and filling tuple data the tuple_init_field_map must be
 * called!
 *
 * @param size  tuple->bsize
 */
struct tuple *
tuple_alloc(struct tuple_format *format, size_t size);

/**
 * Fill field map of tuple by the data in it
 * Used after tuple_alloc call and filling tuple data.
 * Throws an error if tuple data does not match the format.
 */
void
tuple_init_field_map(struct tuple_format *format, struct tuple *tuple);

/**
 * Free the tuple.
 * @pre tuple->refs  == 0
 */
void
tuple_delete(struct tuple *tuple);

/**
 * Check tuple data correspondence to space format;
 * throw proper exception if smth wrong.
 */
void
tuple_validate(struct tuple_format *format, struct tuple *tuple);

/**
 * Check tuple data correspondence to space format;
 * throw proper exception if smth wrong.
 * data argument expected to be a proper msgpack array
 */
void
tuple_validate_raw(struct tuple_format *format, const char *data);

/**
 * Throw and exception about tuple reference counter overflow.
 */
void
tuple_ref_exception();

/**
 * Increment tuple reference counter.
 * Throws if overflow detected.
 *
 * @pre tuple->refs + count >= 0
 */
inline void
tuple_ref(struct tuple *tuple)
{
	if (tuple->refs + 1 > TUPLE_REF_MAX)
		tuple_ref_exception();

	tuple->refs++;
}

/**
 * Decrement tuple reference counter. If it has reached zero, free the tuple.
 *
 * @pre tuple->refs + count >= 0
 */
inline void
tuple_unref(struct tuple *tuple)
{
	assert(tuple->refs - 1 >= 0);

	tuple->refs--;

	if (tuple->refs == 0)
		tuple_delete(tuple);
}

/** Make tuple references exception-friendly in absence of @finally. */
struct TupleRef {
	struct tuple *tuple;
	TupleRef(struct tuple *arg) :tuple(arg) { tuple_ref(tuple); }
	~TupleRef() { tuple_unref(tuple); }
	TupleRef(const TupleRef &) = delete;
	void operator=(const TupleRef&) = delete;
};

/** Make tuple references exception-friendly in absence of @finally. */
struct TupleRefNil {
	struct tuple *tuple;
	TupleRefNil (struct tuple *arg) :tuple(arg)
	{ if (tuple) tuple_ref(tuple); }
	~TupleRefNil() { if (tuple) tuple_unref(tuple); }

	TupleRefNil(const TupleRefNil&) = delete;
	void operator=(const TupleRefNil&) = delete;
};

/**
* @brief Return a tuple format instance
* @param tuple tuple
* @return tuple format instance
*/
static inline struct tuple_format *
tuple_format(const struct tuple *tuple)
{
	struct tuple_format *format = tuple_format_by_id(tuple->format_id);
	assert(tuple_format_id(format) == tuple->format_id);
	return format;
}

/**
 * @brief Return the number of fields in tuple
 * @param tuple
 * @return the number of fields in tuple
 */
inline uint32_t
tuple_field_count(const struct tuple *tuple)
{
	const char *data = tuple->data;
	return mp_decode_array(&data);
}

/**
 * Get a field by id from an non-indexed tuple.
 * Returns a pointer to BER-length prefixed field.
 *
 * @returns field data if field exists or NULL
 */
inline const char *
tuple_field_raw(const char *data, uint32_t bsize, uint32_t i)
{
	const char *pos = data;
	uint32_t size = mp_decode_array(&pos);
	if (unlikely(i >= size))
		return NULL;
	for (uint32_t k = 0; k < i; k++) {
		mp_next(&pos);
	}
	(void)bsize;
	assert(pos <= data + bsize);
	return pos;
}

/**
 * Get a field from tuple by index.
 * Returns a pointer to BER-length prefixed field.
 *
 * @pre field < tuple->field_count.
 * @returns field data if field exists or NULL
 */
inline const char *
tuple_field_old(const struct tuple_format *format,
		const struct tuple *tuple, uint32_t i)
{
	if (likely(i < format->field_count)) {
		/* Indexed field */

		if (i == 0) {
			const char *pos = tuple->data;
			mp_decode_array(&pos);
			return pos;
		}

		if (format->fields[i].offset_slot != INT32_MAX) {
			uint32_t *field_map = (uint32_t *) tuple;
			int32_t slot = format->fields[i].offset_slot;
			return tuple->data + field_map[slot];
		}
	}
	ERROR_INJECT(ERRINJ_TUPLE_FIELD, return NULL);
	return tuple_field_raw(tuple->data, tuple->bsize, i);
}

/**
 * @brief Return field data of the field
 * @param tuple tuple
 * @param field_no field number
 * @param field pointer where the start of field data will be stored,
 *        or NULL if field is out of range
 * @param len pointer where the len of the field will be stored
 */
static inline const char *
tuple_field(const struct tuple *tuple, uint32_t i)
{
	return tuple_field_old(tuple_format(tuple), tuple, i);
}

/**
 * A convenience shortcut for data dictionary - get a tuple field
 * as uint32_t.
 */
inline uint32_t
tuple_field_u32(struct tuple *tuple, uint32_t i)
{
	const char *field = tuple_field(tuple, i);
	if (field == NULL)
		tnt_raise(ClientError, ER_NO_SUCH_FIELD, i);
	if (mp_typeof(*field) != MP_UINT)
		tnt_raise(ClientError, ER_FIELD_TYPE, i + INDEX_OFFSET,
			  field_type_strs[FIELD_TYPE_UNSIGNED]);

	uint64_t val = mp_decode_uint(&field);
	if (val > UINT32_MAX)
		tnt_raise(ClientError, ER_FIELD_TYPE, i + INDEX_OFFSET,
			  field_type_strs[FIELD_TYPE_UNSIGNED]);
	return (uint32_t) val;
}

/**
 * A convenience shortcut for data dictionary - get a tuple field
 * as a NUL-terminated string - returns a string of up to 256 bytes.
 */
const char *
tuple_field_cstr(struct tuple *tuple, uint32_t i);

/** Helper method for the above function. */
const char *
tuple_field_to_cstr(const char *field, uint32_t len);

/**
 * @brief Tuple Interator
 */
struct tuple_iterator {
	/** @cond false **/
	/* State */
	struct tuple *tuple;
	/** Always points to the beginning of the next field. */
	const char *pos;
	/** @endcond **/
	/** field no of the next field. */
	int fieldno;
};

/**
 * @brief Initialize an iterator over tuple fields
 *
 * A workflow example:
 * @code
 * struct tuple_iterator it;
 * tuple_rewind(&it, tuple);
 * const char *field;
 * uint32_t len;
 * while ((field = tuple_next(&it, &len)))
 *	lua_pushlstring(L, field, len);
 *
 * @endcode
 *
 * @param[out] it tuple iterator
 * @param[in]  tuple tuple
 */
inline void
tuple_rewind(struct tuple_iterator *it, struct tuple *tuple)
{
	it->tuple = tuple;
	it->pos = tuple->data;
	(void) mp_decode_array(&it->pos); /* Skip array header */
	it->fieldno = 0;
}

/**
 * @brief Position the iterator at a given field no.
 *
 * @retval field  if the iterator has the requested field
 * @retval NULL   otherwise (iteration is out of range)
 */
const char *
tuple_seek(struct tuple_iterator *it, uint32_t field_no);

/**
 * @brief Iterate to the next field
 * @param it tuple iterator
 * @return next field or NULL if the iteration is out of range
 */
const char *
tuple_next(struct tuple_iterator *it);

/**
 * A convenience shortcut for the data dictionary - get next field
 * from iterator as uint32_t or raise an error if there is
 * no next field.
 */
inline uint32_t
tuple_next_u32(struct tuple_iterator *it)
{
	uint32_t fieldno = it->fieldno;
	const char *field = tuple_next(it);
	if (field == NULL)
		tnt_raise(ClientError, ER_NO_SUCH_FIELD, it->fieldno);
	if (mp_typeof(*field) != MP_UINT)
		tnt_raise(ClientError, ER_FIELD_TYPE, fieldno + INDEX_OFFSET,
			  field_type_strs[FIELD_TYPE_UNSIGNED]);

	uint32_t val = mp_decode_uint(&field);
	if (val > UINT32_MAX)
		tnt_raise(ClientError, ER_FIELD_TYPE, fieldno + INDEX_OFFSET,
			  field_type_strs[FIELD_TYPE_UNSIGNED]);
	return (uint32_t) val;
}

/**
 * A convenience shortcut for the data dictionary - get next field
 * from iterator as a C string or raise an error if there is no
 * next field.
 */
const char *
tuple_next_cstr(struct tuple_iterator *it);

/**
 * Extract key from tuple by given key definition and return
 * buffer allocated on box_txn_alloc with this key.
 * @param tuple - tuple from which need to extract key
 * @param key_def - definition of key that need to extract
 * @param key_size - here will be size of extracted key
 */
char *
tuple_extract_key(const struct tuple *tuple, struct key_def *key_def,
		  uint32_t *key_size);

/**
 * Extract key from raw msgpuck by given key definition and return
 * buffer allocated on box_txn_alloc with this key.
 * @param data - msgpuck data from which need to extract key
 * @param data_end - pointer at the end of data
 * @param key_def - definition of key that need to extract
 * @param key_size - here will be size of extracted key
 */
char *
tuple_extract_key_raw(const char *data, const char *data_end,
		      struct key_def *key_def, uint32_t *key_size);

struct tuple *
tuple_update(struct tuple_format *new_format,
	     tuple_update_alloc_func f, void *alloc_ctx,
	     const struct tuple *old_tuple,
	     const char *expr, const char *expr_end, int field_base);

struct tuple *
tuple_upsert(struct tuple_format *new_format,
	     void *(*region_alloc)(void *, size_t), void *alloc_ctx,
	     const struct tuple *old_tuple,
	     const char *expr, const char *expr_end, int field_base);


/**
 * @brief Compare two tuples using field by field using key definition
 * @param tuple_a tuple
 * @param tuple_b tuple
 * @param key_def key definition
 * @retval 0  if key_fields(tuple_a) == key_fields(tuple_b)
 * @retval <0 if key_fields(tuple_a) < key_fields(tuple_b)
 * @retval >0 if key_fields(tuple_a) > key_fields(tuple_b)
 */
int
tuple_compare_default(const struct tuple *tuple_a, const struct tuple *tuple_b,
	      const struct key_def *key_def);

/**
 * @brief Compare two tuples field by field for duplicate using key definition
 * @param tuple_a tuple
 * @param tuple_b tuple
 * @param key_def key definition
 * @retval 0  if key_fields(tuple_a) == key_fields(tuple_b) and
 * tuple_a == tuple_b - tuple_a is the same object as tuple_b
 * @retval <0 if key_fields(tuple_a) <= key_fields(tuple_b)
 * @retval >0 if key_fields(tuple_a > key_fields(tuple_b)
 */
int
tuple_compare_dup(const struct tuple *tuple_a, const struct tuple *tuple_b,
		  const struct key_def *key_def);

/**
 * @brief Compare a tuple with a key field by field using key definition
 * @param tuple_a tuple
 * @param key BER-encoded key
 * @param part_count number of parts in \a key
 * @param key_def key definition
 * @retval 0  if key_fields(tuple_a) == parts(key)
 * @retval <0 if key_fields(tuple_a) < parts(key)
 * @retval >0 if key_fields(tuple_a) > parts(key)
 */
int
tuple_compare_with_key_default(const struct tuple *tuple_a, const char *key,
		       uint32_t part_count, const struct key_def *key_def);


inline int
tuple_compare_with_key(const struct tuple *tuple, const char *key,
		       uint32_t part_count, const struct key_def *key_def)
{
	return key_def->tuple_compare_with_key(tuple, key, part_count, key_def);
}

inline int
tuple_compare(const struct tuple *tuple_a, const struct tuple *tuple_b,
	      const struct key_def *key_def)
{
	return key_def->tuple_compare(tuple_a, tuple_b, key_def);
}


/** These functions are implemented in tuple_convert.cc. */

/* Store tuple in the output buffer in iproto format. */
int
tuple_to_obuf(struct tuple *tuple, struct obuf *buf);

/**
 * \copydoc box_tuple_to_buf()
 */
ssize_t
tuple_to_buf(const struct tuple *tuple, char *buf, size_t size);

/** Initialize tuple library */
void
tuple_init(float alloc_arena_max_size, uint32_t slab_alloc_minimal,
	   uint32_t slab_alloc_maximal, float alloc_factor);

/** Cleanup tuple library */
void
tuple_free();

void
tuple_begin_snapshot();

void
tuple_end_snapshot();

extern struct tuple *box_tuple_last;

/**
 * Convert internal `struct tuple` to public `box_tuple_t`.
 * \post \a tuple ref counted until the next call.
 * \post tuple_ref() doesn't fail at least once
 * \sa tuple_ref
 * \throw ER_TUPLE_REF_OVERFLOW
 */
static inline box_tuple_t *
tuple_bless(struct tuple *tuple)
{
	assert(tuple != NULL);
	/* Ensure tuple can be referenced at least once after return */
	if (tuple->refs + 2 > TUPLE_REF_MAX)
		tuple_ref_exception();
	tuple->refs++;
	/* Remove previous tuple */
	if (likely(box_tuple_last != NULL))
		tuple_unref(box_tuple_last); /* do not throw */
	/* Remember current tuple */
	box_tuple_last = tuple;
	return tuple;
}

static inline void
mp_tuple_assert(const char *tuple, const char *tuple_end)
{
	assert(mp_typeof(*tuple) == MP_ARRAY);
#ifndef NDEBUG
	mp_next(&tuple);
#endif
	assert(tuple == tuple_end);
	(void) tuple;
	(void) tuple_end;
}

static inline uint32_t
box_tuple_field_u32(box_tuple_t *tuple, uint32_t field_no, uint32_t deflt)
{
	const char *field = box_tuple_field(tuple, field_no);
	if (field != NULL && mp_typeof(*field) == MP_UINT)
		return mp_decode_uint(&field);
	return deflt;
}

#endif /* defined(__cplusplus) */

#endif /* TARANTOOL_BOX_TUPLE_H_INCLUDED */

