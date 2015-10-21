#ifndef IRMIN_H
#define IRMIN_H

/* Bindings to the Irmin database library
   https://github.com/mirage/irmin/
*/

/*
 * Types
 */
typedef struct irmin_repository irmin_repository_t;
typedef struct irmin_store irmin_store_t;
typedef struct irmin_history irmin_history_t;
enum irmin_walk_action {
  irmin_walk_stop,
  irmin_walk_continue
};
typedef enum irmin_walk_action irmin_walk_action_t;

/*
 * Operations on repositories
 */
irmin_repository_t *irmin_repository_create(void);

void irmin_repository_destroy(irmin_repository_t *);

irmin_store_t *irmin_repository_master_store(irmin_repository_t *);

/*
 * Operations on stores
 */
void irmin_store_destroy(irmin_store_t *);

void irmin_store_append(irmin_store_t *,
			char */* key */,
			char */* value */);

char *irmin_store_read(irmin_store_t *,
		       char */* key */);

void irmin_store_update_head(irmin_store_t *, char *);

irmin_history_t *irmin_store_history(irmin_store_t *);

/*
 * Operations on histories
 */
void irmin_history_destroy(irmin_history_t *);

void irmin_history_walk(irmin_history_t *,
			irmin_walk_action_t (char */* key */));

#endif /* IRMIN_H */
