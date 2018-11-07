###############################################################################
#               _____                      _  ______ _____                    #
#              /  ___|                    | | | ___ \  __ \                   #
#              \ `--. _ __ ___   __ _ _ __| |_| |_/ / |  \/                   #
#               `--. \ '_ ` _ \ / _` | '__| __|    /| | __                    #
#              /\__/ / | | | | | (_| | |  | |_| |\ \| |_\ \                   #
#              \____/|_| |_| |_|\__,_|_|   \__\_| \_|\____/ Inc.              #
#                                                                             #
###############################################################################
#                                                                             #
#                       copyright 2018 by SmartRG, Inc.                       #
#                              Santa Barbara, CA                              #
#                                                                             #
###############################################################################
#                                                                             #
# Author: tim.hayes@smartrg.com                                               #
#                                                                             #
# Purpose: Multicast packet accelerator manager                               #
#                                                                             #
###############################################################################
SRC = mcast-pa.c intel.c
OBJ = $(SRC:.c=.o)
DEP = $(SRC:.c=.d)

LIBS=-lpcap
LIBS+=-lrt
LIBS+=-lnetlink
LIBS+=-lmcastfapi

LDFLAGS=$(HOST_LDFLAGS) -L$(STAGING_DIR)/usr/lib/mcast/
EXTRA_CFLAGS += -fPIC -O -g -Wall -Werror -I. 

all: mcast-pa

%.o: %.c
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -c -o $@ $^ 

mcast-pa: $(OBJ)
	$(CC) $(LDFLAGS) -o $@ $^ $(LIBS)

clean:
	rm -f *.o mcast-pa
